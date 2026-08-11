import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

/// Best-effort URL enrichment for the Add Item flow, run entirely on-device
/// (no Edge Function required):
///
///  1. Detect the platform (YouTube / TikTok / Instagram / generic web).
///  2. Try oEmbed first (YouTube, TikTok - no auth), then fall back to
///     scraping OpenGraph/`<meta>` tags.
///  3. If a GROQ_API_KEY is present in the bundled env, polish the title into a
///     short caption, a one-sentence summary, and 2-4 topic tags.
///
/// Returns null on total failure - callers must always let the user save the
/// raw URL regardless (spec section 16). Never throws.
Future<LinkMetadata?> resolveLinkMetadata(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;

  try {
    final platform = _detectPlatform(uri);

    var partial = await _fetchOEmbed(platform, url);
    if (partial == null || partial.title == null) {
      final og = await _fetchOpenGraph(url);
      partial = LinkMetadata(
        title: partial?.title ?? og?.title,
        description: partial?.description ?? og?.description,
        thumbnailUrl: partial?.thumbnailUrl ?? og?.thumbnailUrl,
        platform: platform,
      );
    }

    var meta = LinkMetadata(
      title: partial.title,
      description: partial.description,
      thumbnailUrl: partial.thumbnailUrl,
      platform: platform,
    );

    meta = await _polishWithGroq(meta);
    return meta;
  } catch (_) {
    return null;
  }
}

String _detectPlatform(Uri uri) {
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
  if (host == 'youtu.be' || host.endsWith('youtube.com')) return 'youtube';
  if (host.endsWith('tiktok.com')) return 'tiktok';
  if (host.endsWith('instagram.com')) return 'instagram';
  return 'web';
}

Future<Map<String, dynamic>?> _getJson(String url) async {
  try {
    final res = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'TwinsApp/1.0'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<LinkMetadata?> _fetchOEmbed(String platform, String url) async {
  final encoded = Uri.encodeComponent(url);
  if (platform == 'youtube') {
    final data = await _getJson('https://www.youtube.com/oembed?url=$encoded&format=json');
    if (data == null) return null;
    return LinkMetadata(title: data['title'] as String?, thumbnailUrl: data['thumbnail_url'] as String?);
  }
  if (platform == 'tiktok') {
    final data = await _getJson('https://www.tiktok.com/oembed?url=$encoded');
    if (data == null) return null;
    return LinkMetadata(title: data['title'] as String?, thumbnailUrl: data['thumbnail_url'] as String?);
  }
  return null;
}

String? _extractMeta(String html, String property) {
  final patterns = [
    RegExp('<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']*)["\']', caseSensitive: false),
    RegExp('<meta[^>]+content=["\']([^"\']*)["\'][^>]+property=["\']$property["\']', caseSensitive: false),
    RegExp('<meta[^>]+name=["\']$property["\'][^>]+content=["\']([^"\']*)["\']', caseSensitive: false),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(html);
    if (m != null) return m.group(1);
  }
  return null;
}

Future<LinkMetadata?> _fetchOpenGraph(String url) async {
  try {
    final res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; TwinsBot/1.0)'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final html = res.body;
    return LinkMetadata(
      title: _extractMeta(html, 'og:title') ?? _extractMeta(html, 'twitter:title'),
      description: _extractMeta(html, 'og:description') ?? _extractMeta(html, 'description'),
      thumbnailUrl: _extractMeta(html, 'og:image') ?? _extractMeta(html, 'twitter:image'),
    );
  } catch (_) {
    return null;
  }
}

/// Polishes metadata with Groq if a key is configured. The key is read from the
/// bundled env, so it ships in the app - see SECURITY note in `.env`. On any
/// failure this returns the input metadata unchanged.
Future<LinkMetadata> _polishWithGroq(LinkMetadata meta) async {
  final apiKey = dotenv.isInitialized ? dotenv.maybeGet('GROQ_API_KEY') : null;
  if (apiKey == null || apiKey.isEmpty || meta.title == null) return meta;

  try {
    final res = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'messages': [
              {
                'role': 'system',
                'content':
                    'You clean up social-media video/link titles for a private bookmarking app. '
                        'Given a raw title and description, respond ONLY with JSON: '
                        '{"title": string, "summary": string, "tags": string[]}. '
                        'title: a short punchy version of the original (under 60 chars, keep emoji). '
                        'summary: one short sentence describing the content. '
                        'tags: 2-4 lowercase single-word topic tags, no hashtags.',
              },
              {
                'role': 'user',
                'content': 'Title: ${meta.title}\nDescription: ${meta.description ?? ''}',
              },
            ],
            'temperature': 0.4,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return meta;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return meta;
    final content = (choices.first as Map?)?['message']?['content'] as String?;
    if (content == null) return meta;
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    final tags = (parsed['tags'] as List?)
            ?.whereType<String>()
            .map((t) => t.trim().toLowerCase().replaceFirst(RegExp(r'^#'), ''))
            .where((t) => t.isNotEmpty && t.length <= 24)
            .take(4)
            .toList() ??
        const <String>[];

    final polishedTitle = parsed['title'] as String?;
    final summary = parsed['summary'] as String?;
    return LinkMetadata(
      title: (polishedTitle != null && polishedTitle.trim().isNotEmpty) ? polishedTitle.trim() : meta.title,
      description: (summary != null && summary.trim().isNotEmpty) ? summary.trim() : meta.description,
      thumbnailUrl: meta.thumbnailUrl,
      platform: meta.platform,
      tags: tags,
    );
  } catch (_) {
    return meta;
  }
}
