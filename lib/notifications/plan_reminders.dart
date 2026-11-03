import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/event.dart';
import '../utils/formatters.dart';

/// Reminders for plans, as alarms on this phone. Each twin's phone sets its
/// own from the shared calendar, so a reminder goes off on time even offline
/// and costs nothing on the server. The twin's phone hears about a new plan
/// through the push that announces it (see [applyPush]); the calendar stream
/// keeps everything in line whenever the app is open.
class PlanReminders {
  PlanReminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static final _taps = StreamController<String>.broadcast();

  static const _routePrefix = '/event/';
  static const _channel = AndroidNotificationDetails(
    'plans',
    'Plan reminders',
    channelDescription: 'Reminders for plans on your shared calendar',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static Future<void> init() async {
    if (_ready || !Platform.isAndroid) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) _taps.add(route);
        },
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Routes from tapped reminders: the one that launched the app, then any
  /// tapped while it runs.
  static Stream<String> tappedRoutes() async* {
    if (!_ready) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final route = launch?.didNotificationLaunchApp == true ? launch?.notificationResponse?.payload : null;
    if (route != null && route.isNotEmpty) yield route;
    yield* _taps.stream;
  }

  /// Android 13+ asks before an app may post notifications at all.
  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
  }

  static int _idFor(String eventId) => int.parse(eventId.replaceAll('-', '').substring(0, 7), radix: 16);

  /// Makes this phone's alarms match [events]: one per upcoming plan with a
  /// reminder still ahead, none for anything cancelled or past.
  static Future<void> sync(List<TwinsEvent> events) async {
    if (!_ready) return;
    final now = DateTime.now();
    final wanted = <int, TwinsEvent>{};
    for (final event in events) {
      final at = event.remindAt;
      if (event.isCancelled || at == null || !at.isAfter(now)) continue;
      wanted[_idFor(event.id)] = event;
    }
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if ((request.payload ?? '').startsWith(_routePrefix) && !wanted.containsKey(request.id)) {
          await _plugin.cancel(id: request.id);
        }
      }
      for (final event in wanted.values) {
        await _schedule(
          eventId: event.id,
          title: event.title,
          startsAt: event.startsAt,
          allDay: event.allDay,
          remindAt: event.remindAt!,
        );
      }
    } catch (_) {
      // Alarms are a nicety; the calendar itself never depends on them.
    }
  }

  /// A plan push from the twin (data fields set by the notify function):
  /// set or drop the reminder without waiting for the app to open.
  static Future<void> applyPush(Map<String, dynamic> data) async {
    if (data['kind'] != 'event') return;
    await init();
    if (!_ready) return;
    final eventId = data['event_id'] as String?;
    final startsRaw = data['starts_at'] as String?;
    if (eventId == null || startsRaw == null) return;
    final id = _idFor(eventId);
    final minutes = int.tryParse(data['remind_minutes'] as String? ?? '');
    final cancelled = data['cancelled'] == 'true';
    try {
      await _plugin.cancel(id: id);
      if (cancelled || minutes == null) return;
      final startsAt = DateTime.parse(startsRaw).toLocal();
      final allDay = data['all_day'] == 'true';
      final base = allDay ? DateTime(startsAt.year, startsAt.month, startsAt.day, 9) : startsAt;
      final remindAt = base.subtract(Duration(minutes: minutes));
      if (!remindAt.isAfter(DateTime.now())) return;
      await _schedule(
        eventId: eventId,
        title: data['title'] as String? ?? 'A plan',
        startsAt: startsAt,
        allDay: allDay,
        remindAt: remindAt,
      );
    } catch (_) {}
  }

  static Future<void> _schedule({
    required String eventId,
    required String title,
    required DateTime startsAt,
    required bool allDay,
    required DateTime remindAt,
  }) async {
    final when = tz.TZDateTime.from(remindAt.toUtc(), tz.UTC);
    final body = allDay ? 'Today' : _leadIn(startsAt.difference(remindAt), startsAt);
    final details = const NotificationDetails(android: _channel);
    try {
      await _plugin.zonedSchedule(
        id: _idFor(eventId),
        scheduledDate: when,
        notificationDetails: details,
        // Plain exact alarms get pushed back up to an hour on some phones
        // (realme, for one); alarm-clock ones always ring on time.
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        title: '⏰ $title',
        body: body,
        payload: '$_routePrefix$eventId',
      );
    } catch (_) {
      // Exact alarms switched off for the app: a few minutes late beats none.
      await _plugin.zonedSchedule(
        id: _idFor(eventId),
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '⏰ $title',
        body: body,
        payload: '$_routePrefix$eventId',
      );
    }
  }

  static String _leadIn(Duration ahead, DateTime startsAt) {
    final at = formatClockTime(startsAt);
    if (ahead.inMinutes <= 0) return 'Now · $at';
    return 'In ${formatLeadTime(ahead.inMinutes)} · $at';
  }
}
