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
/// in it straight away, and on their profile so the other twin sees it. The
/// phone's copy remembers whose pick it was: both twins may sign in on the
/// same phone, and one's colour must never land on the other's profile.
class MyColorNotifier extends StateNotifier<TwinColor> {
  MyColorNotifier() : super(TwinColor.miku) {
    _load();
  }

  /// Who [state] belongs to, once known.
  String? _owner;

  Future<void> _load() async {
    final stored = _parse((await SharedPreferences.getInstance()).getString(_prefKey));
    if (stored == null) return;
    _owner = stored.owner;
    state = stored.color;
  }

  /// Stored as "userId:colour".
  static ({String owner, TwinColor color})? _parse(String? raw) {
    if (raw == null) return null;
    final split = raw.lastIndexOf(':');
    if (split <= 0) return null;
    return (owner: raw.substring(0, split), color: TwinColor.fromKey(raw.substring(split + 1)));
  }

  Future<void> _remember(String owner, TwinColor color) async {
    _owner = owner;
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, '$owner:${color.name}');
    await _setLauncherIcon(color);
  }

  Future<void> set(TwinColor color, TwinsRepository repo) async {
    final me = repo.currentProfile;
    if (me == null) return;
    await _remember(me.id, color);
    await repo.updateProfile(themeColor: color.name);
  }

  /// After sign-in the profile is the truth: whoever signed in gets their own
  /// colour, whatever this phone showed before.
  Future<void> syncWithProfile(Profile profile, TwinsRepository repo) async {
    final theirs = TwinColor.fromKey(profile.themeColor);
    if (_owner == profile.id && theirs == state) return;
    await _remember(profile.id, theirs);
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
