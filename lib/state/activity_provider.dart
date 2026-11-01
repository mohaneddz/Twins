import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_providers.dart';
import 'data_providers.dart';

const _seenPrefKey = 'twins_activity_seen_at';

/// When this phone last opened Activity. Everything the other twin did after
/// it counts as unread. A fresh install starts "caught up" rather than
/// flagging the whole history.
class ActivitySeenAtNotifier extends StateNotifier<DateTime?> {
  ActivitySeenAtNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_seenPrefKey);
    if (stored == null) {
      await markAllRead();
    } else {
      state = DateTime.fromMillisecondsSinceEpoch(stored);
    }
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    state = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seenPrefKey, now.millisecondsSinceEpoch);
  }
}

final activitySeenAtProvider = StateNotifierProvider<ActivitySeenAtNotifier, DateTime?>((ref) => ActivitySeenAtNotifier());

/// How many items and messages the other twin added since Activity was last
/// opened - the badge on the bell.
final unreadActivityCountProvider = Provider.family<int, String>((ref, spaceId) {
  final seenAt = ref.watch(activitySeenAtProvider);
  final me = ref.watch(authStateProvider).valueOrNull;
  if (seenAt == null || me == null) return 0;
  final items = ref.watch(recentItemsProvider(spaceId)).valueOrNull ?? const [];
  final messages = ref.watch(recentMessagesProvider(spaceId)).valueOrNull ?? const [];
  return items.where((i) => i.createdBy != me.id && i.createdAt.isAfter(seenAt)).length +
      messages.where((m) => m.authorId != me.id && m.createdAt.isAfter(seenAt)).length;
});
