import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Contextual, frequency-limited reminders.
///
/// The design goals are: never spam, never run an expensive background
/// process, and never be required for using the app. Everything here is
/// driven from foreground app events only, so there is no persistent
/// background service and no extra battery drain.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'evplug_reminders';
  static const String _channelName = 'EVPlug Reminders';

  // The 6-hour EVPlug reminder.
  static const String _reminderTitle = 'EVPlug Reminder ⚡';
  static const String _reminderBody =
      'Check nearby EV charging stations and plan your next charge.';

  // Android's alarm API has no "every 6 hours" repeat interval,
  // so the reminder is scheduled as individual exact alarms at the
  // next 6-hour marks. Scheduling a rolling horizon and refreshing
  // it on every app start keeps the reminder alive even when the
  // app is closed, without ever stacking duplicate schedules.
  static const Duration _reminderInterval = Duration(hours: 6);
  static const int _reminderFirstId = 2000;
  static const int _reminderCount = 28; // 7 days ahead

  // Throttle windows. Stored as last-shown timestamps in preferences.
  static const Duration _chargingReminderInterval = Duration(hours: 20);
  static const Duration _nearbyStationInterval = Duration(hours: 12);

  static const String _lastChargingReminderKey =
      'last_charging_reminder_ms';
  static const String _lastNearbyStationKey = 'last_nearby_station_ms';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _requestInProgress = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tzdata.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      await _plugin.initialize(
        const InitializationSettings(android: androidSettings),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Charging and nearby station reminders',
          importance: Importance.defaultImportance,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Schedules the 6-hour EVPlug reminder.
  ///
  /// Safe to call on every app start: the existing reminder alarms
  /// are cancelled first, so restarting the app refreshes the
  /// schedule instead of creating a second set of them.
  Future<void> scheduleSixHourReminders() async {
    await initialize();

    if (!_initialized) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Exact alarms need the user's permission on Android 12+.
    // Fall back to inexact alarms rather than failing silently.
    final canExact = await android?.canScheduleExactNotifications();
    final scheduleMode = (canExact == false)
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : AndroidScheduleMode.exactAllowWhileIdle;

    // Clear the existing reminders first so this never
    // produces duplicate schedules.
    for (var i = 0; i < _reminderCount; i++) {
      await android?.cancel(_reminderFirstId + i);
    }

    var mark = _nextSixHourMark(tz.TZDateTime.now(tz.local));

    for (var i = 0; i < _reminderCount; i++) {
      try {
        await _plugin.zonedSchedule(
          _reminderFirstId + i,
          _reminderTitle,
          _reminderBody,
          mark,
          _reminderDetails(),
          androidScheduleMode: scheduleMode,
          payload: 'evplug_reminder',
        );
      } catch (e) {
        debugPrint('NotificationService reminder schedule failed: $e');
      }
      mark = mark.add(_reminderInterval);
    }
  }

  /// The next wall-clock mark on the 6-hour grid (00:00, 06:00,
  /// 12:00, 18:00), strictly after [now].
  tz.TZDateTime _nextSixHourMark(tz.TZDateTime now) {
    final gridHour = (now.hour ~/ 6) * 6;
    var mark = tz.TZDateTime(now.location, now.year, now.month, now.day, gridHour);

    if (!mark.isAfter(now)) {
      mark = mark.add(_reminderInterval);
    }

    return mark;
  }

  NotificationDetails _reminderDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Charging and nearby station reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
  }

  /// Asks for notification permission. Failure is non-fatal: the app
  /// remains fully usable without notifications.
  Future<void> requestPermission() async {
    if (!_initialized || _requestInProgress) return;

    _requestInProgress = true;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('NotificationService permission request failed: $e');
    } finally {
      _requestInProgress = false;
    }
  }

  /// Called once when the Home screen is first built. Asks for permission
  /// at a natural moment rather than on cold start.
  Future<void> onHomeLoaded() async {
    await initialize();
    await requestPermission();
    await _evaluateChargingReminder();
  }

  /// Shows a nearby-station notification only when a genuinely close
  /// station exists and the throttle window has elapsed.
  Future<void> onStationsLoaded({double? nearestStationKm}) async {
    if (!_initialized) return;

    if (nearestStationKm == null) return;

    // Only a station within walking distance is worth interrupting for.
    if (nearestStationKm > 2) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final lastShown =
        prefs.getInt(_lastNearbyStationKey) ?? 0;

    if (now - lastShown < _nearbyStationInterval.inMilliseconds) return;

    await prefs.setInt(_lastNearbyStationKey, now);

    final distanceText = nearestStationKm < 1
        ? '${(nearestStationKm * 1000).round()} m'
        : '${nearestStationKm.toStringAsFixed(1)} km';

    await _show(
      id: 1001,
      title: 'Charging station near you',
      body: 'A charging station is $distanceText away.',
    );
  }

  /// Battery-aware charging reminder based on the vehicle range stored in
  /// the user profile. Only fires inside the throttle window.
  Future<void> _evaluateChargingReminder() async {
    if (!_initialized) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final lastShown = prefs.getInt(_lastChargingReminderKey) ?? 0;

    if (now - lastShown < _chargingReminderInterval.inMilliseconds) {
      return;
    }

    final rangeKm = await _readEstimatedRangeKm(user.uid);

    // Without vehicle information we cannot make the reminder contextual,
    // so it is skipped rather than sent as a random message.
    if (rangeKm == null || rangeKm <= 0) return;

    await prefs.setInt(_lastChargingReminderKey, now);

    await _show(
      id: 1000,
      title: 'Charging reminder',
      body:
          'Do you need to charge your vehicle? '
          'Your ${rangeKm.toStringAsFixed(0)} km range can cover about '
          '${(rangeKm * 0.2).toStringAsFixed(0)} km on a reserve of 20 km.',
    );
  }

  Future<double?> _readEstimatedRangeKm(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      return double.tryParse(
        doc.data()?['estimatedRangeKm']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('NotificationService vehicle lookup failed: $e');
      return null;
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Charging and nearby station reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}
