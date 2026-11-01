import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoNamePrefKey = 'twins_chat_auto_name_after';

/// How many messages an unnamed chat collects before it's named
/// automatically (once). Set in Settings → Chats.
class ChatAutoNameAfterNotifier extends StateNotifier<int> {
  ChatAutoNameAfterNotifier() : super(1) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_autoNamePrefKey) ?? 1;
  }

  Future<void> set(int messages) async {
    state = messages;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoNamePrefKey, messages);
  }
}

final chatAutoNameAfterProvider = StateNotifierProvider<ChatAutoNameAfterNotifier, int>((ref) => ChatAutoNameAfterNotifier());

const _renamePrefKey = 'twins_chat_rename_every';

/// How many more messages an auto-named chat collects before it gets a
/// fresh name; 0 keeps the first name for good.
class ChatRenameEveryNotifier extends StateNotifier<int> {
  ChatRenameEveryNotifier() : super(20) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_renamePrefKey) ?? 20;
  }

  Future<void> set(int messages) async {
    state = messages;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_renamePrefKey, messages);
  }
}

final chatRenameEveryProvider = StateNotifierProvider<ChatRenameEveryNotifier, int>((ref) => ChatRenameEveryNotifier());
