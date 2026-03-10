import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/task_model.dart';
import '../models/birthday_model.dart';

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
  static String defaultNotifMusic = 'mixkit-happy-bells-notification-937.mp3';
  static double defaultNotifVolume = 1.0; // 0.0–1.0
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
        sound: RawResourceAndroidNotificationSound(
            'mixkit_happy_bells_notification_937'),
        enableVibration: true,
      ),
    );

    // Birthday channel – high importance, festive notification sound
    await ap?.deleteNotificationChannel('birthday_channel');
    await ap?.createNotificationChannel(
      const AndroidNotificationChannel(
        'birthday_channel',
        'Birthday Reminders',
        description: 'Pengingat ulang tahun',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
            'mixkit_happy_bells_notification_937'),
        enableVibration: true,
      ),
    );

    // Pomodoro channel – high importance, notification sound
    await ap?.deleteNotificationChannel('pomodoro_channel');
    await ap?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pomodoro_channel',
        'Pomodoro Timer',
        description: 'Pomodoro timer notifications',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alarm_clock'),
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
      final mins = reminderMinutes(remindersToUse[i]);
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
              sound: const RawResourceAndroidNotificationSound(
                  'mixkit_happy_bells_notification_937'),
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

  // ── Schedule due-date reminders ────────────────────────────────────────────
  // When the task's alarmMode == alarmMusic, every due-date reminder also fires
  // as a full-screen alarm (same alarm channel) so AlarmScreen opens and the
  // configured alarm music plays.  When notificationOnly, a quiet reminder is
  // shown instead (subject to DND).
  static Future<void> scheduleDueReminders(TaskModel task) async {
    if (!task.dueDateEnabled || task.dueDate == null) return;
    if (!task.dueReminderEnabled || task.dueReminders.isEmpty) return;

    final dueTime = task.dueTime;
    final dueDt = DateTime(
      task.dueDate!.year,
      task.dueDate!.month,
      task.dueDate!.day,
      dueTime?.hour ?? 23,
      dueTime?.minute ?? 59,
    );

    // Due reminders always follow the task's main alarmMode so that alarm-mode
    // tasks consistently show AlarmScreen for ALL their reminders.
    final useAlarmChannel = task.alarmMode == AlarmMode.alarmMusic;

    for (int i = 0; i < task.dueReminders.length; i++) {
      final mins = reminderMinutes(task.dueReminders[i]);
      if (mins == null) continue;
      final remind = dueDt.subtract(Duration(minutes: mins));
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
              sound: const RawResourceAndroidNotificationSound(
                  'mixkit_happy_bells_notification_937'),
              enableVibration: vibrationEnabled,
            );

      await _plugin.zonedSchedule(
        _dueReminderId(task.id, i),
        useAlarmChannel
            ? '⏰  Due ${task.dueReminders[i]}: ${task.title}'
            : '🔔  Due ${task.dueReminders[i]}: ${task.title}',
        'Due at ${task.dueTimeLabel ?? 'end of day'}',
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

  // ── Subtask & Checklist Item Reminders ─────────────────────────────────────
  // Schedule notification reminders for subtasks with due dates
  static Future<void> scheduleSubTaskReminders(TaskModel task) async {
    await _scheduleSubTaskRemindersRecursive(task.id, task.subTasks);
  }

  static Future<void> _scheduleSubTaskRemindersRecursive(
      String taskId, List<SubTask> subtasks) async {
    for (final st in subtasks) {
      // Schedule reminder for this subtask if configured
      if (st.dueReminderEnabled && st.dueDate != null) {
        await _scheduleSubTaskNotification(taskId, st);
      }
      // Note: Checklist items within subtasks don't have their own reminders
      // They are simple items with just id, title, and isChecked status
    }
  }

  // Removed scheduleChecklistItemReminders method as ChecklistItem
  // only has id, title, and isChecked - no reminder functionality

  static Future<void> _scheduleSubTaskNotification(
      String taskId, SubTask subtask) async {
    if (subtask.dueDate == null) return;

    final dueTime = subtask.dueTime;
    final dueDt = DateTime(
      subtask.dueDate!.year,
      subtask.dueDate!.month,
      subtask.dueDate!.day,
      dueTime?.hour ?? 23,
      dueTime?.minute ?? 59,
    );

    // Schedule reminder 1 hour before due date (default for subtasks)
    final remindTime = dueDt.subtract(const Duration(hours: 1));
    if (remindTime.isBefore(DateTime.now())) return;

    final remindTz = tz.TZDateTime.from(remindTime, tz.local);

    // Skip if DND is enabled and time falls within quiet hours
    if (dndEnabled && _isDndTime(remindTz)) return;

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Task Reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
          'mixkit_happy_bells_notification_937'),
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _subtaskReminderId(taskId, subtask.id),
      '📋  Subtask Due Soon: ${subtask.title}',
      subtask.dueTime != null
          ? 'Due at ${_formatTime(subtask.dueTime!)}'
          : 'Due today',
      remindTz,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: taskId,
    );
  }

  // Note: ChecklistItem no longer supports reminders
  // Removed _scheduleChecklistItemNotification method

  // ── Cancel ────────────────────────────────────────────────────────────────

  /// Cancels only the alarm notification (not reminders).
  /// Call this before pushing AlarmScreen so the notification sound stops
  /// immediately and doesn't overlap with the in-app audio.
  static Future<void> cancelAlarmOnly(String taskId) async {
    await _plugin.cancel(_alarmId(taskId));
  }

  static Future<void> cancelTaskAlarm(String taskId) async {
    await _plugin.cancel(_alarmId(taskId));
    for (int i = 0; i < 6; i++) {
      await _plugin.cancel(_reminderId(taskId, i));
    }
    // Also cancel due-date reminder notifications
    for (int i = 0; i < 6; i++) {
      await _plugin.cancel(_dueReminderId(taskId, i));
    }
    // Cancel subtask reminders
    await cancelSubTaskReminders(taskId);
    // Note: Checklist items don't have reminders
  }

  static Future<void> cancelSubTaskReminders(String taskId) async {
    // Cancel up to 50 subtask reminders (supports up to 50 subtasks per task)
    for (int i = 0; i < 50; i++) {
      await _plugin.cancel(_subtaskReminderId(taskId, i.toString()));
    }
  }

  // Removed cancelChecklistItemReminders as ChecklistItem doesn't support reminders

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Birthday Reminders ────────────────────────────────────────────────────
  // Schedules 4 notifications for the next birthday occurrence:
  //   index 0 → 3 days before  (sebentar lagi ulang tahun)
  //   index 1 → 2 days before  (sebentar lagi ulang tahun)
  //   index 2 → 1 day  before  (besok ulang tahun)
  //   index 3 → on the day     (selamat ulang tahun!)
  // All fire at 09:00 local time.  Notifications already in the past are skipped.
  static Future<void> scheduleBirthdayReminders(BirthdayEntry entry) async {
    final nextBirthday = _nextBirthdayDate(entry.month, entry.day);

    // [daysOffset, notifIndex]
    const schedule = [
      [3, 0],
      [2, 1],
      [1, 2],
      [0, 3],
    ];

    for (final item in schedule) {
      final daysOffset = item[0];
      final idx = item[1];

      final notifDate = nextBirthday.subtract(Duration(days: daysOffset));
      final notifDt =
          DateTime(notifDate.year, notifDate.month, notifDate.day, 9, 0);

      if (notifDt.isBefore(DateTime.now())) continue;

      final notifTz = tz.TZDateTime.from(notifDt, tz.local);

      final String title;
      final String body;

      if (entry.type == BirthdayType.self) {
        if (daysOffset == 0) {
          title = '🎂 Selamat Ulang Tahun!';
          body =
              'Hari ini ulang tahunmu! Semoga hari-harimu penuh kebahagiaan 🎉🎊';
        } else if (daysOffset == 1) {
          title = '🎂 Reminder Ulang Tahun';
          body = 'Besok ulang tahunmu! Siapkan perayaanmu 🥳';
        } else {
          title = '🎂 Reminder Ulang Tahun';
          body =
              'Sebentar lagi ulang tahunmu! Tinggal $daysOffset hari lagi 🎉';
        }
      } else {
        final name = entry.name;
        if (daysOffset == 0) {
          title = '🎂 Selamat Ulang Tahun $name!';
          body = 'Hari ini ulang tahun $name! Jangan lupa ucapkan selamat 🎊';
        } else if (daysOffset == 1) {
          title = '🎂 Reminder Ulang Tahun $name';
          body = 'Besok $name ulang tahun! Jangan lupa ucapkan selamat 🎁';
        } else {
          title = '🎂 Reminder Ulang Tahun $name';
          body =
              'Sebentar lagi $name ulang tahun! Tinggal $daysOffset hari lagi';
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'birthday_channel',
        'Birthday Reminders',
        channelDescription: 'Pengingat ulang tahun',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(
            'mixkit_happy_bells_notification_937'),
        enableVibration: vibrationEnabled,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        _birthdayReminderId(entry.id, idx),
        title,
        body,
        notifTz,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'birthday_${entry.id}',
      );
    }
  }

  /// Cancels all 4 birthday reminder notifications for [entryId].
  static Future<void> cancelBirthdayReminders(String entryId) async {
    for (int i = 0; i < 4; i++) {
      await _plugin.cancel(_birthdayReminderId(entryId, i));
    }
  }

  // ── Pomodoro Timer Notifications ──────────────────────────────────────────
  static Future<void> showPomodoroNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Timer',
      channelDescription: 'Pomodoro timer notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm_clock'),
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      99999, // Constant ID for Pomodoro notifications
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static int _alarmId(String id) => id.hashCode.abs() % 2147483647;
  static int _reminderId(String id, int i) =>
      (_alarmId(id) + i + 1) % 2147483647;
  static int _dueReminderId(String id, int i) =>
      (_alarmId(id) + 200 + i) % 2147483647;

  // Birthday notification IDs use offset 500–503 to avoid collision with
  // task offsets (1–6 for start reminders, 200–206 for due reminders).
  static int _birthdayBaseId(String id) => id.hashCode.abs() % 2147483647;
  static int _birthdayReminderId(String id, int i) =>
      (_birthdayBaseId(id) + 500 + i) % 2147483647;

  // Subtask notification IDs use offset 1000+ to avoid collision
  static int _subtaskReminderId(String taskId, String subtaskId) =>
      ('${taskId}_subtask_$subtaskId'.hashCode.abs() + 1000) % 2147483647;

  // Removed _checklistItemReminderId as ChecklistItem doesn't support reminders

  /// Returns the next calendar date (at midnight) on which [month]/[day]
  /// occurs.  If today is already that date, returns today so the on-day
  /// notification can be scheduled at 09:00.  Rolls over to next year when
  /// the date has already passed completely.
  static DateTime _nextBirthdayDate(int month, int day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(now.year, month, day);
    if (next.isBefore(today)) {
      next = DateTime(now.year + 1, month, day);
    }
    return next;
  }

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

  /// Converts a reminder label string to minutes offset.
  /// Made public so foreground alarm checker in main.dart can reuse it.
  static int? reminderMinutes(String label) {
    if (label.contains('1 Day')) return 1440;
    if (label.contains('3 Hours')) return 180;
    if (label.contains('1 Hour')) return 60;
    if (label.contains('30 Min')) return 30;
    if (label.contains('15 Min')) return 15;
    if (label.contains('5 Min')) return 5;
    return null;
  }

  /// Formats a TimeOfDay to HH:MM string
  static String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
