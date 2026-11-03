import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'twins_plan_default_reminder';

/// Stored for "no reminder", since a missing key means "never chosen".
const _none = -1;

/// The reminder a new plan starts with, in minutes before it (null for
/// none). Set in Settings → Calendar; a plan can still pick its own.
class PlanDefaultReminderNotifier extends StateNotifier<int?> {
  PlanDefaultReminderNotifier() : super(60) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefKey);
    if (stored != null) state = stored == _none ? null : stored;
  }

  Future<void> set(int? minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, minutes ?? _none);
  }
}

final planDefaultReminderProvider =
    StateNotifierProvider<PlanDefaultReminderNotifier, int?>((ref) => PlanDefaultReminderNotifier());

/// The reminder choices offered everywhere, in minutes (null = none).
const planReminderChoices = <int?>[null, 0, 10, 30, 60, 120, 1440];
