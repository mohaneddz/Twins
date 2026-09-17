import '../supabase/supabase_client_provider.dart';

/// AI tagging, run server-side via the `suggest-tags` Edge Function (no AI
/// provider key ships in the client bundle). Given an item's text and the
/// space's existing tag catalog, it picks the tags that best describe the
/// item, STRONGLY preferring to reuse catalog tags and only inventing a new
/// one when nothing fits. Returns lowercase tag names, or an empty list on
/// any failure - callers must treat tagging as best-effort and always let
/// the user save without it.
Future<List<String>> suggestTags({
  required String title,
  String? description,
  String? content,
  String? url,
  String? platform,
  required List<String> catalog,
  int max = 4,
}) async {
  try {
    final res = await supa.functions.invoke('suggest-tags', body: {
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'platform': platform,
      'catalog': catalog,
      'max': max,
    });
    final data = res.data as Map<String, dynamic>?;
    return (data?['tags'] as List?)?.whereType<String>().toList() ?? const [];
  } catch (_) {
    return const [];
  }
}
