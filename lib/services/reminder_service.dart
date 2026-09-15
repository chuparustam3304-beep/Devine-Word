import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules (or cancels) the repeating daily-reminder notification.
///
/// Every call is fail-safe: on platforms without the plugin (desktop,
/// widget tests) or when the OS blocks a permission, the reminder simply
/// doesn't get scheduled — a missing reminder must never crash the app.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const _channelId = 'daily_reminder';

  /// Stable id so every re-schedule replaces the previous alarm.
  static const _notificationId = 20260101;

  /// Approved notification copy (see screens/09-notification mockup).
  static const String title = "Today's ayah is ready";
  static const String body =
      'Make space for your routine — your verse for today is waiting.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Loads the timezone database and the device's IANA zone. Only the
  /// first call does work; later calls return immediately.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // No plugin (tests/unsupported): tz.local stays UTC and the
      // schedule below still no-ops through its own guards.
    }
    _initialized = true;
  }

  /// Turns the reminder on at [minutes] past midnight (0–1439), or off.
  /// Scheduling with the same id replaces any previous alarm, so the
  /// toggle and the time picker can both just call this.
  Future<void> sync({required bool enabled, required int minutes}) async {
    await init();
    try {
      if (!enabled) {
        await _plugin.cancel(id: _notificationId);
        return;
      }
      final exact = await _ensurePermissions();

      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      final now = tz.TZDateTime.now(tz.local);
      var fire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!fire.isAfter(now)) fire = fire.add(const Duration(days: 1));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily reminder',
          channelDescription: 'A new verse every day',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title,
        body: body,
        scheduledDate: fire,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Missing platform channel (widget tests) or scheduling blocked
      // by the OS — stay silent.
    }
  }

  /// Asks the OS for notification permission on first schedule and
  /// returns whether exact alarms are available (Android 12+ may deny;
  /// the caller then falls back to an inexact daily window).
  Future<bool> _ensurePermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android =
            _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        await android?.requestNotificationsPermission();
        final canExact = await android?.canScheduleExactNotifications();
        if (canExact == false) {
          await android?.requestExactAlarmsPermission();
          return (await android?.canScheduleExactNotifications()) ?? false;
        }
        return canExact ?? false;
      }
    } catch (_) {}
    return false;
  }
}
