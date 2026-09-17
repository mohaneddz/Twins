import '../supabase/supabase_client_provider.dart';

/// Names a chat thread from its first few messages, run server-side via the
/// `name-chat` Edge Function (no AI provider key ships in the client
/// bundle). Returns null on any failure - callers must treat naming as
/// best-effort and leave the chat unnamed (or let the user name it
/// manually) rather than block on it.
Future<String?> suggestChatName(List<String> messageBodies) async {
  try {
    final res = await supa.functions.invoke('name-chat', body: {'messages': messageBodies});
    final data = res.data as Map<String, dynamic>?;
    return data?['name'] as String?;
  } catch (_) {
    return null;
  }
}
