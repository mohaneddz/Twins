import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/repositories/twins_repository.dart';
import 'plan_reminders.dart';

/// Runs in its own isolate when a push lands while the app is closed or in
/// the background: a plan push carries the plan's time so the reminder alarm
/// can be set (or dropped) right away.
@pragma('vm:entry-point')
Future<void> _onBackgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PlanReminders.applyPush(message.data);
}

/// Push notifications through the app's single Firebase project. This phone's
/// token is stored in the pair's own Supabase (device_tokens) so their
/// `notify` function can reach it; nothing is kept in Firebase itself.
class PushNotifications {
  PushNotifications._();

  static bool _ready = false;

  /// A tapped notification's route waiting for the home screen to show, the
  /// same way cold-start shares wait (a push over the splash gets dropped).
  static String? pendingRoute;
  static StreamSubscription<String>? _refreshSub;

  /// Safe to call once at startup; push simply stays off if Firebase isn't
  /// configured (tests, non-Android).
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_onBackgroundPush);
      FirebaseMessaging.onMessage.listen((message) => PlanReminders.applyPush(message.data));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Asks for notification permission (Android 13+) and records this phone
  /// for the signed-in twin. Call once they're in their space.
  static Future<void> register(TwinsRepository repo) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await repo.registerDeviceToken(token);
      _refreshSub ??= messaging.onTokenRefresh.listen((t) => repo.registerDeviceToken(t).catchError((_) {}));
    } catch (_) {
      // No Play Services or offline: the app works fine without push.
    }
  }

  /// On log out: stop this phone receiving the signed-in twin's pushes.
  static Future<void> unregister(TwinsRepository repo) async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) await repo.unregisterDeviceToken(token);
      await _refreshSub?.cancel();
      _refreshSub = null;
      await messaging.deleteToken();
    } catch (_) {}
  }

  /// Routes from tapped notifications: the one that launched the app, then
  /// any tapped while it runs in the background.
  static Stream<String> tappedRoutes() async* {
    if (!_ready) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final route = initial?.data['route'];
    if (route is String && route.isNotEmpty) yield route;
    yield* FirebaseMessaging.onMessageOpenedApp
        .map((message) => message.data['route'])
        .where((route) => route is String && route.isNotEmpty)
        .cast<String>();
  }
}
