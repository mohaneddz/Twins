import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// AI tagging, baked into the app (Groq, key from the bundled env - same
/// tradeoff as link enrichment). Given an item's text and the space's existing
/// tag catalog, it picks the tags that best describe the item, STRONGLY
/// preferring to reuse catalog tags and only inventing a new one when nothing
/// fits. Returns lowercase tag names (a subset of [catalog] plus at most a
/// couple of new ones), or an empty list on any failure - callers must treat
/// tagging as best-effort and always let the user save without it.
Future<List<String>> suggestTags({
  required String title,
  String? description,
  String? content,
  String? url,
  String? platform,
  required List<String> catalog,
  int max = 4,
}) async {
  final apiKey = dotenv.isInitialized ? dotenv.maybeGet('GROQ_API_KEY') : null;
  if (apiKey == null || apiKey.isEmpty) return const [];

  final text = [
    if (title.trim().isNotEmpty) 'Title: $title',
    if (description != null && description.trim().isNotEmpty) 'Description: $description',
    if (content != null && content.trim().isNotEmpty) 'Content: ${content.length > 500 ? content.substring(0, 500) : content}',
    // The URL/platform alone is a useful signal when preview enrichment failed
    // (e.g. a youtube.com/... music link should still get #music).
    if (platform != null && platform.isNotEmpty && platform != 'device') 'Platform: $platform',
    if (url != null && url.trim().isNotEmpty) 'URL: $url',
  ].join('\n');
  if (text.trim().isEmpty) return const [];

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
                    'You tag saved items (videos, links, notes, images) for a private bookmarking app shared by two friends. '
                        'You are given an item and the existing tag catalog. Choose 1 to $max tags that best describe the item. '
                        'STRONGLY prefer reusing tags from the catalog; only invent a NEW tag when nothing in the catalog fits. '
                        'Respond ONLY with JSON: {"tags": string[]}. Each tag: lowercase, one or two words, no "#", no emoji.',
              },
              {
                'role': 'user',
                'content': 'Catalog: ${catalog.isEmpty ? '(empty)' : catalog.join(', ')}\n\nItem:\n$text',
              },
            ],
            'temperature': 0.3,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return const [];
    final raw = (choices.first as Map?)?['message']?['content'] as String?;
    if (raw == null) return const [];
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final tags = (parsed['tags'] as List?)
            ?.whereType<String>()
            .map((t) => t.trim().toLowerCase().replaceFirst(RegExp(r'^#'), ''))
            .where((t) => t.isNotEmpty && t.length <= 24)
            .toSet()
            .take(max)
            .toList() ??
        const <String>[];
    return tags;
  } catch (_) {
    return const [];
  }
}
