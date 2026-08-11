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
