import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _greetingPrefKey = 'twins_show_greeting';

/// Whether the home screen shows the "Hey twins!" line under the logo. Off
/// unless turned on in Settings, since it reads as a second title.
class ShowGreetingNotifier extends StateNotifier<bool> {
  ShowGreetingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_greetingPrefKey) ?? false;
  }

  Future<void> set(bool show) async {
    state = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_greetingPrefKey, show);
  }
}

final showGreetingProvider = StateNotifierProvider<ShowGreetingNotifier, bool>((ref) => ShowGreetingNotifier());
