import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/habit.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  static const String _channelId = 'habit_reminders_channel_v2';
  static const String _channelName = 'Nhắc nhở thói quen';
  static const String _channelDesc = 'Thông báo hàng ngày nhắc bạn duy trì thói quen và kỷ luật';

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Configure and sync Local TimeZone (vital: match device offset)
    _configureLocalTimeZone();

    // 2. Android & iOS initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);

      // 3. Pre-create high priority Notification Channel on Android 8.0+
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImpl.createNotificationChannel(channel);
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully. tz.local: ${tz.local.name}');
    } catch (e) {
      debugPrint('[NotificationService] Init error: $e');
    }
  }

  void _configureLocalTimeZone() {
    tz.initializeTimeZones();
    try {
      final now = DateTime.now();
      final timeZoneName = now.timeZoneName;

      // Try matching by timezone name
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      }

      // Try matching by exact millisecond offset (e.g. UTC+7 for Vietnam)
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == offsetMs) {
          tz.setLocalLocation(location);
          return;
        }
      }

      // Fallback: If UTC+7 (Vietnam / Bangkok / Jakarta)
      if (now.timeZoneOffset.inHours == 7) {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone match fallback: $e');
    }
  }

  Future<void> requestPermissions() async {
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // Notification permission for Android 13+
      await androidImpl.requestNotificationsPermission();
      // Exact alarm permission for Android 12+
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleHabitReminder(Habit habit) async {
    if (habit.reminderTime == null || habit.reminderTime!.isEmpty) return;

    final parts = habit.reminderTime!.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final notifId = habit.id.hashCode & 0x7fffffff;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final now = tz.TZDateTime.now(tz.local);
    final secondsUntil = scheduledDate.difference(now).inSeconds;

    debugPrint('[NotificationService] Scheduling "${habit.title}" at $scheduledDate (in $secondsUntil seconds)');

    try {
      await _notificationsPlugin.zonedSchedule(
        notifId,
        '⏰ Thời gian cho thói quen: ${habit.title}',
        habit.description.isNotEmpty
            ? habit.description
            : 'Đã đến giờ thực hiện thói quen hôm nay để duy trì chuỗi kỷ luật!',
        scheduledDate,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
      );
    } catch (exactError) {
      debugPrint('[NotificationService] exactAllowWhileIdle failed, falling back to inexact: $exactError');
      // Graceful fallback for devices restricting exact alarms (MIUI / HyperOS)
      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          '⏰ Thời gian cho thói quen: ${habit.title}',
          habit.description.isNotEmpty ? habit.description : 'Đã đến giờ hoàn thành thói quen!',
          scheduledDate,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (fallbackError) {
        debugPrint('[NotificationService] Schedule failed completely: $fallbackError');
      }
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _notificationsPlugin.show(999999, title, body, details);
  }

  Future<void> cancelHabitReminder(String habitId) async {
    final notifId = habitId.hashCode & 0x7fffffff;
    try {
      await _notificationsPlugin.cancel(notifId);
    } catch (e) {
      debugPrint('[NotificationService] Cancel error: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] CancelAll error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0,
    );

    // If time has already passed today (or is less than 5 seconds from now), schedule for tomorrow
    if (scheduledDate.isBefore(now) || scheduledDate.difference(now).inSeconds < 5) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
