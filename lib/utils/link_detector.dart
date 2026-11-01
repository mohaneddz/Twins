import '../data/models/item_type.dart';

class DetectedLink {
  final ItemType type;
  final ItemPlatform platform;
  const DetectedLink(this.type, this.platform);
}

/// Best-effort client-side classification of a pasted URL. The real
/// title/thumbnail/description enrichment happens server-side via the
/// resolve-link Edge Function (see supabase/functions/resolve-link) - this
/// only decides which icon/renderer to use immediately while that request
/// is in flight, and as a fallback if it fails.
DetectedLink detectLink(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';

  if (host.contains('youtu.be') || host.contains('youtube.com')) {
    if (path.contains('/shorts/')) return const DetectedLink(ItemType.short, ItemPlatform.youtube);
    return const DetectedLink(ItemType.youtube, ItemPlatform.youtube);
  }
  if (host.contains('tiktok.com')) {
    return const DetectedLink(ItemType.tiktok, ItemPlatform.tiktok);
  }
  if (host.contains('instagram.com')) {
    return const DetectedLink(ItemType.reel, ItemPlatform.instagram);
  }
  return const DetectedLink(ItemType.link, ItemPlatform.web);
}

final _urlPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// Turns whatever another app shared into the link to save: picks the URL out
/// of share text like "Check this out https://vm.tiktok.com/…", then
/// canonicalizes it. Text without a URL comes back unchanged.
String linkFromSharedText(String text) {
  final match = _urlPattern.firstMatch(text);
  if (match == null) return text.trim();
  return canonicalLink(match.group(0)!.replaceAll(RegExp(r'[).,!?]+$'), ''));
}

/// Rewrites YouTube's many URL shapes (m., music., youtu.be, share params
/// like si/pp/feature/list) to www.youtube.com/watch?v=… or /shorts/…. The
/// mobile site in particular serves no description, so previews of m. links
/// came back with YouTube's generic tagline.
String canonicalLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return url.trim();
  final host = uri.host.toLowerCase();
  final isYouTube = host == 'youtu.be' || host == 'youtube.com' || host.endsWith('.youtube.com');
  if (!isYouTube) return url.trim();

  final segments = uri.pathSegments;
  String? id;
  var shorts = false;
  if (host == 'youtu.be') {
    id = segments.isEmpty ? null : segments.first;
  } else if (uri.queryParameters['v'] != null) {
    id = uri.queryParameters['v'];
  } else if (segments.length >= 2 && const ['shorts', 'live', 'embed'].contains(segments.first)) {
    id = segments[1];
    shorts = segments.first == 'shorts';
  }
  if (id == null || id.isEmpty) return uri.replace(host: 'www.youtube.com').toString();

  final start = uri.queryParameters['t'];
  final query = {
    if (!shorts) 'v': id,
    if (start != null && start.isNotEmpty) 't': start,
  };
  return Uri.https('www.youtube.com', shorts ? '/shorts/$id' : '/watch', query.isEmpty ? null : query).toString();
}
