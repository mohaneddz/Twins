import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

class LinkMetadata {
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? platform;

  /// AI-suggested topic tags from the Groq polish step (may be empty).
  final List<String> tags;

  const LinkMetadata({
    this.title,
    this.description,
    this.thumbnailUrl,
    this.platform,
    this.tags = const [],
  });
}

/// Best-effort URL enrichment for the Add Item flow, delegated entirely to
/// the `resolve-link` Edge Function (oEmbed/OpenGraph fetch + optional Groq
/// polish all run server-side, so no AI provider key ever ships in the
/// client bundle).
///
/// Returns null on total failure - callers must always let the user save the
/// raw URL regardless (spec section 16). Never throws.
Future<LinkMetadata?> resolveLinkMetadata(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;

  try {
    final res = await supa.functions.invoke('resolve-link', body: {'url': url});
    final data = res.data as Map<String, dynamic>?;
    if (data == null) return null;
    return LinkMetadata(
      title: data['title'] as String?,
      description: data['description'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
      platform: data['platform'] as String?,
      tags: (data['tags'] as List?)?.whereType<String>().toList() ?? const [],
    );
  } on FunctionException {
    return null;
  } catch (_) {
    return null;
  }
}
