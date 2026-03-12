import 'package:flutter/material.dart';

enum HabitFrequency { daily, weekly, monthly }

enum HabitCategory {
  health,
  fitness,
  learning,
  mindfulness,
  productivity,
  social,
  other
}

class HabitModel {
  final String id;
  final String title;
  final String description;
  final HabitCategory category;
  final HabitFrequency frequency;
  final List<bool> weekDays; // Sun=0 .. Sat=6 (used when frequency == weekly)
  final int targetCount; // completions needed per occurrence (≥1)
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;
  final DateTime startDate;
  final DateTime? endDate;
  final Color colorTag;
  final Map<String, int> completionLog; // "yyyy-MM-dd" → completed count
  final bool isArchived;
  final List<String> history;

  const HabitModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.frequency,
    required this.weekDays,
    required this.targetCount,
    required this.reminderEnabled,
    this.reminderTime,
    required this.startDate,
    this.endDate,
    required this.colorTag,
    required this.completionLog,
    this.isArchived = false,
    required this.history,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int completionCountOn(DateTime date) => completionLog[dateKey(date)] ?? 0;

  bool isCompletedOn(DateTime date) => completionCountOn(date) >= targetCount;

  /// True when this habit should occur on [date] based on frequency settings.
  bool shouldOccurOn(DateTime date) {
    final start = DateUtils.dateOnly(startDate);
    final check = DateUtils.dateOnly(date);
    if (check.isBefore(start)) return false;
    if (endDate != null && check.isAfter(DateUtils.dateOnly(endDate!))) {
      return false;
    }
    switch (frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.weekly:
        // weekDays is [Sun=0, Mon=1 .. Sat=6]; DateTime.weekday Mon=1..Sun=7
        final idx = check.weekday % 7; // Sun→0, Mon→1 .. Sat→6
        return weekDays[idx];
      case HabitFrequency.monthly:
        return check.day == start.day;
    }
  }

  // ── Streak calculation ────────────────────────────────────────────────────
  int get currentStreak {
    final today = DateUtils.dateOnly(DateTime.now());
    int streak = 0;
    var cursor = today;
    while (true) {
      if (!shouldOccurOn(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
        if (cursor.isBefore(DateUtils.dateOnly(startDate))) break;
        continue;
      }
      if (isCompletedOn(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        if (cursor.isBefore(DateUtils.dateOnly(startDate))) break;
      } else {
        // Allow today being incomplete without breaking streak
        if (cursor == today) {
          cursor = cursor.subtract(const Duration(days: 1));
          if (cursor.isBefore(DateUtils.dateOnly(startDate))) break;
          continue;
        }
        break;
      }
    }
    return streak;
  }

  int get longestStreak {
    final start = DateUtils.dateOnly(startDate);
    final end = DateUtils.dateOnly(DateTime.now());
    int best = 0;
    int current = 0;
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (shouldOccurOn(cursor)) {
        if (isCompletedOn(cursor)) {
          current++;
          if (current > best) best = current;
        } else {
          current = 0;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return best;
  }

  // ── Computed labels ────────────────────────────────────────────────────────
  String get categoryLabel {
    switch (category) {
      case HabitCategory.health:
        return 'Health';
      case HabitCategory.fitness:
        return 'Fitness';
      case HabitCategory.learning:
        return 'Learning';
      case HabitCategory.mindfulness:
        return 'Mindfulness';
      case HabitCategory.productivity:
        return 'Productivity';
      case HabitCategory.social:
        return 'Social';
      case HabitCategory.other:
        return 'Other';
    }
  }

  String get frequencyLabel {
    switch (frequency) {
      case HabitFrequency.daily:
        return 'Daily';
      case HabitFrequency.weekly:
        return 'Weekly';
      case HabitFrequency.monthly:
        return 'Monthly';
    }
  }

  String? get reminderTimeLabel {
    if (reminderTime == null) return null;
    final h = reminderTime!.hour.toString().padLeft(2, '0');
    final m = reminderTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  HabitModel copyWith({
    String? id,
    String? title,
    String? description,
    HabitCategory? category,
    HabitFrequency? frequency,
    List<bool>? weekDays,
    int? targetCount,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    Color? colorTag,
    Map<String, int>? completionLog,
    bool? isArchived,
    List<String>? history,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      weekDays: weekDays ?? this.weekDays,
      targetCount: targetCount ?? this.targetCount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime:
          clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      colorTag: colorTag ?? this.colorTag,
      completionLog: completionLog ?? this.completionLog,
      isArchived: isArchived ?? this.isArchived,
      history: history ?? this.history,
    );
  }

  // ── JSON ───────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.index,
        'frequency': frequency.index,
        'weekDays': weekDays,
        'targetCount': targetCount,
        'reminderEnabled': reminderEnabled,
        'reminderTime_hour': reminderTime?.hour,
        'reminderTime_minute': reminderTime?.minute,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'colorTag': colorTag.toARGB32(),
        'completionLog': completionLog,
        'isArchived': isArchived,
        'history': history,
      };

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminderTime;
    if (json['reminderTime_hour'] != null &&
        json['reminderTime_minute'] != null) {
      reminderTime = TimeOfDay(
        hour: json['reminderTime_hour'] as int,
        minute: json['reminderTime_minute'] as int,
      );
    }

    final rawLog = json['completionLog'] as Map<String, dynamic>? ?? {};
    final completionLog = <String, int>{};
    rawLog.forEach((k, v) => completionLog[k] = (v as num).toInt());

    return HabitModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: HabitCategory.values[(json['category'] as int? ?? 0)
          .clamp(0, HabitCategory.values.length - 1)],
      frequency: HabitFrequency.values[(json['frequency'] as int? ?? 0)
          .clamp(0, HabitFrequency.values.length - 1)],
      weekDays: (json['weekDays'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          List.filled(7, false),
      targetCount: json['targetCount'] as int? ?? 1,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderTime: reminderTime,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      colorTag: Color(json['colorTag'] as int? ?? 0xFF7B6EF6),
      completionLog: completionLog,
      isArchived: json['isArchived'] as bool? ?? false,
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}
