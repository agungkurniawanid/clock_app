import 'package:flutter/material.dart';

enum TaskStatus { todo, risk, overdue, completed }

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
  final DateTime date;
  final TimeOfDay time;
  final AlarmMode alarmMode;
  final String? musicFile;
  final int volume;
  final int snoozeMinutes;
  final RepeatType repeat;
  final List<bool> weekDays; // Sun–Sat
  final List<String> reminders;
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
    required this.repeat,
    required this.weekDays,
    required this.reminders,
    required this.colorTag,
    required this.history,
  });

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
    int? volume,
    int? snoozeMinutes,
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
      musicFile: musicFile ?? this.musicFile,
      volume: volume ?? this.volume,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      repeat: repeat ?? this.repeat,
      weekDays: weekDays ?? this.weekDays,
      reminders: reminders ?? this.reminders,
      colorTag: colorTag ?? this.colorTag,
      history: history ?? this.history,
    );
  }

  String get statusLabel {
    switch (status) {
      case TaskStatus.todo:
        return 'Todo';
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
}
