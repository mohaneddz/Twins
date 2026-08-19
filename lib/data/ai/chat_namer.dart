import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Names a chat thread from its first few messages (Groq, key from the
/// bundled env - same tradeoff as tagging/link enrichment). Returns null on
/// any failure - callers must treat naming as best-effort and leave the
/// chat unnamed (or let the user name it manually) rather than block on it.
Future<String?> suggestChatName(List<String> messageBodies) async {
  final apiKey = dotenv.isInitialized ? dotenv.maybeGet('GROQ_API_KEY') : null;
  if (apiKey == null || apiKey.isEmpty) return null;

  final text = messageBodies.take(10).join('\n');
  if (text.trim().isEmpty) return null;

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
                    'You name short chat threads between two close friends sharing a private chat app. Given the '
                        'first few messages, respond with a punchy 2 to 4 word title that captures what they are '
                        'talking about. No quotes, no trailing punctuation, no emoji unless it truly fits. '
                        'Respond ONLY with JSON: {"name": string}.',
              },
              {'role': 'user', 'content': text},
            ],
            'temperature': 0.4,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    final raw = (choices.first as Map?)?['message']?['content'] as String?;
    if (raw == null) return null;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final name = (parsed['name'] as String?)?.trim();
    if (name == null || name.isEmpty || name.length > 60) return null;
    return name;
  } catch (_) {
    return null;
  }
}
