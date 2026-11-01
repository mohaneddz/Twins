import '../supabase/supabase_client_provider.dart';

/// Whether [ChatScreen] should (re)name a chat right now (Settings → Chats):
/// an unnamed chat gets its first name at [nameAfter] messages, and an
/// auto-named one a fresh name every [renameEvery] messages after that
/// (0 = never). A name someone typed ([nameIsAuto] false) is never replaced.
bool shouldAttemptAutoName({
  required bool alreadyNaming,
  required String? chatName,
  required bool nameIsAuto,
  required int? namedAtCount,
  required int messageCount,
  required int nameAfter,
  required int renameEvery,
}) {
  if (alreadyNaming) return false;
  if (chatName == null) return messageCount >= nameAfter;
  if (!nameIsAuto || renameEvery <= 0) return false;
  return messageCount - (namedAtCount ?? 0) >= renameEvery;
}

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
