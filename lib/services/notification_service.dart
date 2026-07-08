import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// Local gym-window reminders. No location permission, no geofencing — the
/// user picks recurring time windows and we schedule local notifications at
/// startMinute + remindAfterMinutes on the chosen weekdays.
///
/// Whether the user actually started a workout is checked when the app next
/// resumes: [rescheduleAll] is called on every launch/resume and after any
/// workout starts, and it skips today's reminder if a session already began.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<bool> init() async {
    if (!isSupported || _ready) return _ready;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      // Permission is requested contextually when the user first creates a
      // gym window, not at app start.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _ready = true;
    return _ready;
  }

  /// Contextual permission request — call at the moment a window is created.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.requestNotificationsPermission() ?? false;
    }
    final impl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await impl?.requestPermissions(alert: true, sound: true) ?? false;
  }

  static const _channel = AndroidNotificationDetails(
    'gym_window',
    'Gym reminders',
    channelDescription: 'Reminders for your planned gym windows',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Reschedules the next 7 days of reminders from scratch.
  /// [workedOutToday] suppresses today's reminder once a session exists.
  Future<void> rescheduleAll(List<GymWindow> windows,
      {required bool workedOutToday}) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var id = 0;
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = now.add(Duration(days: dayOffset));
      for (final w in windows.where((w) => w.enabled)) {
        if (!w.appliesOn(day.weekday)) continue;
        final fireMinute = w.startMinute + w.remindAfterMinutes;
        var fireAt = tz.TZDateTime(tz.local, day.year, day.month, day.day,
            fireMinute ~/ 60, fireMinute % 60);
        if (fireAt.isBefore(now)) continue;
        if (dayOffset == 0 && workedOutToday) continue;
        await _plugin.zonedSchedule(
          id++,
          'Gym time',
          "Your ${_fmt(w.startMinute)}–${_fmt(w.endMinute)} window is open and no workout is logged yet.",
          fireAt,
          const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  /// Snooze: re-fire later the same day (default 30 minutes), but only if it
  /// still lands inside the window.
  Future<void> snooze(GymWindow w, {int minutes = 30}) async {
    if (!isSupported) return;
    await init();
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = now.add(Duration(minutes: minutes));
    final endOfWindow = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, w.endMinute ~/ 60, w.endMinute % 60);
    if (fireAt.isAfter(endOfWindow)) return;
    await _plugin.zonedSchedule(
      9000 + (w.id ?? 0),
      'Gym time (snoozed)',
      'Still time to make your ${_fmt(w.startMinute)}–${_fmt(w.endMinute)} window.',
      fireAt,
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static String _fmt(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m == 0 ? '$h12 $ampm' : '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }
}
