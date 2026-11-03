import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/profile.dart';
import '../data/repositories/twins_repository.dart';
import '../theme/twin_color.dart';
import 'auth_providers.dart';

const _prefKey = 'twins_my_color';
const _iconChannel = MethodChannel('twins/appIcon');

/// The colour this phone's twin picked. Kept on the phone so the app opens
/// in it straight away, and on their profile so the other twin sees it.
class MyColorNotifier extends StateNotifier<TwinColor> {
  MyColorNotifier() : super(TwinColor.miku) {
    _load();
  }

  bool _chosenHere = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null) {
      _chosenHere = true;
      state = TwinColor.fromKey(stored);
    }
  }

  Future<void> set(TwinColor color, TwinsRepository repo) async {
    state = color;
    _chosenHere = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, color.name);
    await _setLauncherIcon(color);
    await repo.updateProfile(themeColor: color.name);
  }

  /// After sign-in: a phone that never picked takes the profile's colour (a
  /// reinstall, or the other phone of the same twin); one that did makes
  /// sure the profile says so too.
  Future<void> syncWithProfile(Profile profile, TwinsRepository repo) async {
    final prefs = await SharedPreferences.getInstance();
    _chosenHere = _chosenHere || prefs.getString(_prefKey) != null;
    if (!_chosenHere) {
      state = TwinColor.fromKey(profile.themeColor);
      await prefs.setString(_prefKey, state.name);
      await _setLauncherIcon(state);
    } else if (profile.themeColor != state.name) {
      await repo.updateProfile(themeColor: state.name);
    }
  }

  static Future<void> _setLauncherIcon(TwinColor color) async {
    try {
      await _iconChannel.invokeMethod('set', {'color': color.name});
    } catch (_) {
      // Tests and non-Android: the icon simply stays as it is.
    }
  }
}

final myColorProvider = StateNotifierProvider<MyColorNotifier, TwinColor>((ref) => MyColorNotifier());

/// The colour to draw [userId]'s things in: mine for me, my twin's for
/// theirs. Should we both pick the same one, theirs gets a stand-in so the
/// two of us never look alike.
final colorOfUserProvider = Provider.family<TwinColor, String?>((ref, userId) {
  final mine = ref.watch(myColorProvider);
  final me = ref.watch(authStateProvider).valueOrNull;
  if (userId == null || userId == me?.id) return mine;
  final space = ref.watch(currentSpaceProvider).valueOrNull;
  final members = space == null ? const <Profile>[] : ref.watch(spaceMembersProvider(space.id)).valueOrNull ?? const <Profile>[];
  final theirs = TwinColor.fromKey(members.where((m) => m.id == userId).firstOrNull?.themeColor);
  return theirs == mine ? mine.standIn : theirs;
});
