import '../supabase/supabase_client_provider.dart';

/// Messages a chat needs before auto-naming is worth attempting.
const autoNameThreshold = 3;

/// Whether [ChatScreen] should attempt to auto-name a chat right now. Fires
/// once per unnamed chat, the first time it reaches [autoNameThreshold]
/// messages - renaming after that is manual only (`chatName` stops being
/// null), so this never re-fires or fights a name the twins picked
/// themselves.
bool shouldAttemptAutoName({
  required bool alreadyNaming,
  required String? chatName,
  required int messageCount,
}) {
  return !alreadyNaming && chatName == null && messageCount >= autoNameThreshold;
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
