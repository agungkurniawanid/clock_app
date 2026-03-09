import 'package:flutter/material.dart';

enum TaskStatus { todo, inProgress, risk, overdue, completed, upcoming }

enum AlarmMode { notificationOnly, alarmMusic }

enum RepeatType { none, daily, weekly, monthly, custom }

enum TaskPriority { low, medium, high }

enum TaskCategory { work, personal, health, study, other }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskStatus status;
  final TaskPriority priority;

  // ── Start Date / Time ──────────────────────────────────────────────────────
  final DateTime date;
  final TimeOfDay time;

  // ── Start Alarm ────────────────────────────────────────────────────────────
  final AlarmMode alarmMode;
  final String? musicFile;
  final int volume;
  final int snoozeMinutes;

  // ── Due Date / Time ────────────────────────────────────────────────────────
  final bool dueDateEnabled;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;

  // ── Due Date Reminders ─────────────────────────────────────────────────────
  final bool dueReminderEnabled;
  final List<String> dueReminders;
  final AlarmMode dueAlarmMode;
  final String? dueMusicFile;
  final int dueVolume;
  final int dueSnoozeMinutes;

  // ── Other ──────────────────────────────────────────────────────────────────
  final RepeatType repeat;
  final List<bool> weekDays; // Sun–Sat
  final List<String> reminders; // start date reminders
  final Color colorTag;
  final List<String> history;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    required this.date,
    required this.time,
    required this.alarmMode,
    this.musicFile,
    required this.volume,
    required this.snoozeMinutes,
    this.dueDateEnabled = false,
    this.dueDate,
    this.dueTime,
    this.dueReminderEnabled = false,
    this.dueReminders = const [],
    this.dueAlarmMode = AlarmMode.notificationOnly,
    this.dueMusicFile,
    this.dueVolume = 100,
    this.dueSnoozeMinutes = 15,
    required this.repeat,
    required this.weekDays,
    required this.reminders,
    required this.colorTag,
    required this.history,
  });

  // ── JSON serialization ─────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.index,
        'status': status.index,
        'priority': priority.index,
        'date': date.toIso8601String(),
        'time_hour': time.hour,
        'time_minute': time.minute,
        'alarmMode': alarmMode.index,
        'musicFile': musicFile,
        'volume': volume,
        'snoozeMinutes': snoozeMinutes,
        'dueDateEnabled': dueDateEnabled,
        'dueDate': dueDate?.toIso8601String(),
        'dueTime_hour': dueTime?.hour,
        'dueTime_minute': dueTime?.minute,
        'dueReminderEnabled': dueReminderEnabled,
        'dueReminders': dueReminders,
        'dueAlarmMode': dueAlarmMode.index,
        'dueMusicFile': dueMusicFile,
        'dueVolume': dueVolume,
        'dueSnoozeMinutes': dueSnoozeMinutes,
        'repeat': repeat.index,
        'weekDays': weekDays,
        'reminders': reminders,
        'colorTag': colorTag.toARGB32(),
        'history': history,
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay? dueTime;
    if (json['dueTime_hour'] != null && json['dueTime_minute'] != null) {
      dueTime = TimeOfDay(
        hour: json['dueTime_hour'] as int,
        minute: json['dueTime_minute'] as int,
      );
    }
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: TaskCategory.values[
          (json['category'] as int).clamp(0, TaskCategory.values.length - 1)],
      status: TaskStatus.values[
          (json['status'] as int).clamp(0, TaskStatus.values.length - 1)],
      priority: TaskPriority.values[
          (json['priority'] as int).clamp(0, TaskPriority.values.length - 1)],
      date: DateTime.parse(json['date'] as String),
      time: TimeOfDay(
        hour: json['time_hour'] as int,
        minute: json['time_minute'] as int,
      ),
      alarmMode: AlarmMode.values[
          (json['alarmMode'] as int).clamp(0, AlarmMode.values.length - 1)],
      musicFile: json['musicFile'] as String?,
      volume: json['volume'] as int,
      snoozeMinutes: json['snoozeMinutes'] as int,
      dueDateEnabled: json['dueDateEnabled'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      dueTime: dueTime,
      dueReminderEnabled: json['dueReminderEnabled'] as bool? ?? false,
      dueReminders: (json['dueReminders'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      dueAlarmMode: AlarmMode.values[(json['dueAlarmMode'] as int? ?? 0)
          .clamp(0, AlarmMode.values.length - 1)],
      dueMusicFile: json['dueMusicFile'] as String?,
      dueVolume: json['dueVolume'] as int? ?? 100,
      dueSnoozeMinutes: json['dueSnoozeMinutes'] as int? ?? 15,
      repeat: RepeatType.values[
          (json['repeat'] as int).clamp(0, RepeatType.values.length - 1)],
      weekDays:
          (json['weekDays'] as List<dynamic>).map((e) => e as bool).toList(),
      reminders:
          (json['reminders'] as List<dynamic>).map((e) => e as String).toList(),
      colorTag: Color(json['colorTag'] as int),
      history:
          (json['history'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  // ── copyWith ──────────────────────────────────────────────────────────────
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskCategory? category,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? date,
    TimeOfDay? time,
    AlarmMode? alarmMode,
    String? musicFile,
    bool clearMusicFile = false,
    int? volume,
    int? snoozeMinutes,
    bool? dueDateEnabled,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? dueReminderEnabled,
    List<String>? dueReminders,
    AlarmMode? dueAlarmMode,
    String? dueMusicFile,
    int? dueVolume,
    int? dueSnoozeMinutes,
    RepeatType? repeat,
    List<bool>? weekDays,
    List<String>? reminders,
    Color? colorTag,
    List<String>? history,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      time: time ?? this.time,
      alarmMode: alarmMode ?? this.alarmMode,
      musicFile: clearMusicFile ? null : (musicFile ?? this.musicFile),
      volume: volume ?? this.volume,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      dueDateEnabled: dueDateEnabled ?? this.dueDateEnabled,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      dueReminderEnabled: dueReminderEnabled ?? this.dueReminderEnabled,
      dueReminders: dueReminders ?? this.dueReminders,
      dueAlarmMode: dueAlarmMode ?? this.dueAlarmMode,
      dueMusicFile: dueMusicFile ?? this.dueMusicFile,
      dueVolume: dueVolume ?? this.dueVolume,
      dueSnoozeMinutes: dueSnoozeMinutes ?? this.dueSnoozeMinutes,
      repeat: repeat ?? this.repeat,
      weekDays: weekDays ?? this.weekDays,
      reminders: reminders ?? this.reminders,
      colorTag: colorTag ?? this.colorTag,
      history: history ?? this.history,
    );
  }

  // ── Computed getters ──────────────────────────────────────────────────────
  String get statusLabel {
    switch (status) {
      case TaskStatus.upcoming:
        return 'Upcoming';
      case TaskStatus.todo:
        return 'Todo';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.risk:
        return 'At Risk';
      case TaskStatus.overdue:
        return 'Overdue';
      case TaskStatus.completed:
        return 'Completed';
    }
  }

  String get categoryLabel {
    switch (category) {
      case TaskCategory.work:
        return 'Work';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.health:
        return 'Health';
      case TaskCategory.study:
        return 'Study';
      case TaskCategory.other:
        return 'Other';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String get repeatLabel {
    switch (repeat) {
      case RepeatType.none:
        return 'No Repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        return 'Custom';
    }
  }

  String get timeLabel {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? get dueDateLabel {
    if (!dueDateEnabled || dueDate == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dueDate!.day} ${months[dueDate!.month - 1]} ${dueDate!.year}';
  }

  String? get dueTimeLabel {
    if (dueTime == null) return null;
    final h = dueTime!.hour.toString().padLeft(2, '0');
    final m = dueTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
