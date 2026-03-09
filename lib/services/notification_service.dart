import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/task_model.dart';

/// Called whenever a notification is tapped (foreground or background).
/// Set this in main.dart before calling [NotificationService.init].
typedef OnNotificationTap = void Function(String taskId);

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Callback wired in main.dart to navigate → AlarmScreen
  static OnNotificationTap? onTap;

  // ── User-configurable settings (set from main.dart after loading prefs) ───
  static bool vibrationEnabled = true;
  static bool dndEnabled = false;
  static String defaultAlarmMusic = 'alarm_clock.mp3';
  static double defaultAlarmVolume = 1.0; // 0.0–1.0
  static String defaultReminder = '1 Hour Before';

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    await _createChannels();
  }

  static Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Delete old channels so they are recreated with the correct sound.
    // If the channel already exists from a previous install, Android keeps
    // the original settings (including no sound) unless we delete + recreate.
    await ap?.deleteNotificationChannel('alarm_channel');
    await ap?.deleteNotificationChannel('reminder_channel');

    // Alarm channel – highest priority, full screen intent, uses alarm tone
    // from res/raw so the notification itself sounds even before AlarmScreen opens.
    await ap?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alarm_channel',
        'Smart Alarm',
        description: 'Task alarms — rings even with screen off',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm_clock'),
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF7B6EF6),
      ),
    );

    // Reminder channel – high but no full-screen
    await ap?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_channel',
        'Task Reminders',
        description: 'Reminder alerts before task start time',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ── Permission request ────────────────────────────────────────────────────
  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await ap?.requestNotificationsPermission();
      await ap?.requestExactAlarmsPermission();
      // Android 14+ requires explicit USE_FULL_SCREEN_INTENT permission so the
      // alarm overlay shows even when the screen is on.
      await ap?.requestFullScreenIntentPermission();
    } else if (Platform.isIOS) {
      final ip = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ip?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── Check launch payload (app opened via notification) ───────────────────
  static Future<void> checkLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        // Small delay to let the widget tree mount
        await Future.delayed(const Duration(milliseconds: 600));
        onTap?.call(payload);
      }
    }
  }

  // ── Notification response handlers ───────────────────────────────────────
  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onTap?.call(payload);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    // payload is stored; will be handled by checkLaunchPayload on next launch
  }

  // ── Schedule alarm (task start time) ─────────────────────────────────────
  static Future<void> scheduleTaskAlarm(TaskModel task) async {
    final scheduled = _tzFrom(task.date, task.time);
    if (scheduled == null) return;

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Smart Alarm',
      channelDescription: 'Task alarms — rings even with screen off',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_clock'),
      enableVibration: vibrationEnabled,
      visibility: NotificationVisibility.public,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    await _plugin.zonedSchedule(
      _alarmId(task.id),
      '⏰  ${task.title}',
      task.description.isNotEmpty
          ? task.description
          : 'Time to start your task!',
      scheduled,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
      matchDateTimeComponents: _repeatComponent(task.repeat),
    );
  }

  // ── Schedule reminders before task start ──────────────────────────────────
  // When alarmMode == alarmMusic the reminder fires as a full-screen alarm
  // (same channel as the main alarm, so the app opens AlarmScreen).
  // When alarmMode == notificationOnly it shows a quiet reminder notification.
  // DND (22:00–07:00) suppresses notificationOnly reminders only.
  static Future<void> scheduleReminders(TaskModel task) async {
    // Use default reminder when task has none configured
    final remindersToUse =
        task.reminders.isNotEmpty ? task.reminders : [defaultReminder];

    final taskDt = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      task.time.hour,
      task.time.minute,
    );

    final useAlarmChannel = task.alarmMode == AlarmMode.alarmMusic;

    for (int i = 0; i < remindersToUse.length; i++) {
      final mins = _reminderMinutes(remindersToUse[i]);
      if (mins == null) continue;
      final remind = taskDt.subtract(Duration(minutes: mins));
      if (remind.isBefore(DateTime.now())) continue;

      final remindTz = tz.TZDateTime.from(remind, tz.local);

      // DND: skip non-alarm notifications that fall within quiet hours
      if (!useAlarmChannel && dndEnabled && _isDndTime(remindTz)) continue;

      final AndroidNotificationDetails androidDetails = useAlarmChannel
          ? AndroidNotificationDetails(
              'alarm_channel',
              'Smart Alarm',
              channelDescription: 'Task alarms — rings even with screen off',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              playSound: true,
              sound: const RawResourceAndroidNotificationSound('alarm_clock'),
              enableVibration: vibrationEnabled,
              visibility: NotificationVisibility.public,
              autoCancel: false,
            )
          : AndroidNotificationDetails(
              'reminder_channel',
              'Task Reminders',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: vibrationEnabled,
            );

      await _plugin.zonedSchedule(
        _reminderId(task.id, i),
        useAlarmChannel
            ? '⏰  ${remindersToUse[i]}: ${task.title}'
            : '🔔  ${remindersToUse[i]}: ${task.title}',
        'Starts at ${task.timeLabel}',
        remindTz,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    }
  }

  // ── Snooze: cancel current alarm and reschedule N minutes later ───────────
  static Future<void> snoozeAlarm(TaskModel task, int snoozeMinutes) async {
    await cancelTaskAlarm(task.id);
    final snoozedDt = DateTime.now().add(Duration(minutes: snoozeMinutes));
    final snoozeTask = task.copyWith(
      date: DateTime(snoozedDt.year, snoozedDt.month, snoozedDt.day),
      time: TimeOfDay(hour: snoozedDt.hour, minute: snoozedDt.minute),
    );
    await scheduleTaskAlarm(snoozeTask);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  static Future<void> cancelTaskAlarm(String taskId) async {
    await _plugin.cancel(_alarmId(taskId));
    for (int i = 0; i < 6; i++) {
      await _plugin.cancel(_reminderId(taskId, i));
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static int _alarmId(String id) => id.hashCode.abs() % 2147483647;
  static int _reminderId(String id, int i) =>
      (_alarmId(id) + i + 1) % 2147483647;

  /// Returns true when [dt] falls within DND quiet hours (22:00 – 07:00).
  static bool _isDndTime(tz.TZDateTime dt) {
    final hour = dt.hour;
    return hour >= 22 || hour < 7;
  }

  static tz.TZDateTime? _tzFrom(DateTime date, TimeOfDay time) {
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (dt.isBefore(DateTime.now())) return null;
    return tz.TZDateTime.from(dt, tz.local);
  }

  static DateTimeComponents? _repeatComponent(RepeatType r) {
    switch (r) {
      case RepeatType.daily:
        return DateTimeComponents.time;
      case RepeatType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      default:
        return null;
    }
  }

  static int? _reminderMinutes(String label) {
    if (label.contains('1 Day')) return 1440;
    if (label.contains('3 Hours')) return 180;
    if (label.contains('1 Hour')) return 60;
    if (label.contains('30 Min')) return 30;
    if (label.contains('15 Min')) return 15;
    if (label.contains('5 Min')) return 5;
    return null;
  }
}
