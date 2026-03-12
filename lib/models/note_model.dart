import 'package:flutter/material.dart';

// ── Reminder type ────────────────────────────────────────────────────────────

enum NoteReminderType {
  intervalDays, // e.g. every N days after last visit
  dayOfMonth, // e.g. every 15th of the month
  oneTime, // a specific date (no/with repeat)
}

// ── Reminder configuration ───────────────────────────────────────────────────

class NoteReminder {
  final NoteReminderType type;
  final int intervalDays; // used by intervalDays
  final int dayOfMonth; // 1‒28, used by dayOfMonth
  final DateTime? specificDate; // used by oneTime
  final bool repeat; // for intervalDays & dayOfMonth: repeat; oneTime: ignored (always once)
  final bool isEnabled;

  const NoteReminder({
    required this.type,
    this.intervalDays = 7,
    this.dayOfMonth = 1,
    this.specificDate,
    this.repeat = true,
    this.isEnabled = true,
  });

  /// Returns the next scheduled reminder date based on [lastVisited].
  /// Returns null if there is no upcoming reminder.
  DateTime? computeNextReminder(DateTime? lastVisited) {
    if (!isEnabled) return null;
    final now = DateTime.now();

    switch (type) {
      case NoteReminderType.intervalDays:
        final base = lastVisited ?? now;
        var next = base.add(Duration(days: intervalDays));
        if (repeat) {
          while (next.isBefore(now)) {
            next = next.add(Duration(days: intervalDays));
          }
        } else {
          if (next.isBefore(now)) return null;
        }
        return next;

      case NoteReminderType.dayOfMonth:
        final day = dayOfMonth.clamp(1, 28);
        var candidate = DateTime(now.year, now.month, day, 9, 0);
        if (!candidate.isAfter(now)) {
          candidate = DateTime(now.year, now.month + 1, day, 9, 0);
        }
        return candidate;

      case NoteReminderType.oneTime:
        if (specificDate == null) return null;
        if (specificDate!.isBefore(now)) return null;
        return specificDate;
    }
  }

  /// True when the reminder was due but the item has not been visited in time.
  bool isOverdue(DateTime? lastVisited) {
    if (!isEnabled) return false;
    final now = DateTime.now();
    switch (type) {
      case NoteReminderType.intervalDays:
        if (lastVisited == null) return false;
        final due = lastVisited.add(Duration(days: intervalDays));
        return due.isBefore(now);

      case NoteReminderType.dayOfMonth:
        final day = dayOfMonth.clamp(1, 28);
        // Overdue if today >= dayOfMonth and not yet visited this month
        final dueThisMonth = DateTime(now.year, now.month, day);
        if (!dueThisMonth.isAfter(now)) {
          // due passed this month — check if last visited was before due
          if (lastVisited == null) return true;
          return lastVisited.isBefore(dueThisMonth);
        }
        return false;

      case NoteReminderType.oneTime:
        if (specificDate == null) return false;
        if (specificDate!.isAfter(now)) return false;
        if (lastVisited == null) return true;
        return lastVisited.isBefore(specificDate!);
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'intervalDays': intervalDays,
        'dayOfMonth': dayOfMonth,
        'specificDate': specificDate?.toIso8601String(),
        'repeat': repeat,
        'isEnabled': isEnabled,
      };

  factory NoteReminder.fromJson(Map<String, dynamic> json) => NoteReminder(
        type: NoteReminderType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NoteReminderType.intervalDays,
        ),
        intervalDays: json['intervalDays'] as int? ?? 7,
        dayOfMonth: json['dayOfMonth'] as int? ?? 1,
        specificDate: json['specificDate'] != null
            ? DateTime.tryParse(json['specificDate'] as String)
            : null,
        repeat: json['repeat'] as bool? ?? true,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  NoteReminder copyWith({
    NoteReminderType? type,
    int? intervalDays,
    int? dayOfMonth,
    DateTime? specificDate,
    bool? repeat,
    bool? isEnabled,
    bool clearSpecificDate = false,
  }) =>
      NoteReminder(
        type: type ?? this.type,
        intervalDays: intervalDays ?? this.intervalDays,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        specificDate:
            clearSpecificDate ? null : (specificDate ?? this.specificDate),
        repeat: repeat ?? this.repeat,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}

// ── NoteFolder ───────────────────────────────────────────────────────────────

class NoteFolder {
  final String id;
  final String title;
  final int colorValue;
  final String? parentFolderId; // null = root
  final NoteReminder? reminder;
  final DateTime? lastVisitedAt;
  final DateTime createdAt;

  const NoteFolder({
    required this.id,
    required this.title,
    this.colorValue = 0xFF7B6EF6,
    this.parentFolderId,
    this.reminder,
    this.lastVisitedAt,
    required this.createdAt,
  });

  bool get isReminderOverdue => reminder?.isOverdue(lastVisitedAt) ?? false;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'colorValue': colorValue,
        'parentFolderId': parentFolderId,
        'reminder': reminder?.toJson(),
        'lastVisitedAt': lastVisitedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteFolder.fromJson(Map<String, dynamic> json) => NoteFolder(
        id: json['id'] as String,
        title: json['title'] as String,
        colorValue: json['colorValue'] as int? ?? 0xFF7B6EF6,
        parentFolderId: json['parentFolderId'] as String?,
        reminder: json['reminder'] != null
            ? NoteReminder.fromJson(json['reminder'] as Map<String, dynamic>)
            : null,
        lastVisitedAt: json['lastVisitedAt'] != null
            ? DateTime.tryParse(json['lastVisitedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  NoteFolder copyWith({
    String? title,
    int? colorValue,
    String? parentFolderId,
    NoteReminder? reminder,
    DateTime? lastVisitedAt,
    bool clearReminder = false,
    bool clearParent = false,
    bool clearLastVisited = false,
  }) =>
      NoteFolder(
        id: id,
        title: title ?? this.title,
        colorValue: colorValue ?? this.colorValue,
        parentFolderId:
            clearParent ? null : (parentFolderId ?? this.parentFolderId),
        reminder: clearReminder ? null : (reminder ?? this.reminder),
        lastVisitedAt:
            clearLastVisited ? null : (lastVisitedAt ?? this.lastVisitedAt),
        createdAt: createdAt,
      );
}

// ── NoteFile ─────────────────────────────────────────────────────────────────

class NoteFile {
  final String id;
  final String title;
  final String content;
  final String? folderId; // null = root
  final int colorValue;
  final NoteReminder? reminder;
  final DateTime? lastVisitedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteFile({
    required this.id,
    required this.title,
    this.content = '',
    this.folderId,
    this.colorValue = 0xFF43D8A5,
    this.reminder,
    this.lastVisitedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isReminderOverdue => reminder?.isOverdue(lastVisitedAt) ?? false;

  Color get color => Color(colorValue);

  /// First non-empty line as a subtitle/preview.
  String get preview {
    final lines = content.trim().split('\n').where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) return 'Empty note';
    return lines.first.trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'folderId': folderId,
        'colorValue': colorValue,
        'reminder': reminder?.toJson(),
        'lastVisitedAt': lastVisitedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NoteFile.fromJson(Map<String, dynamic> json) => NoteFile(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        folderId: json['folderId'] as String?,
        colorValue: json['colorValue'] as int? ?? 0xFF43D8A5,
        reminder: json['reminder'] != null
            ? NoteReminder.fromJson(json['reminder'] as Map<String, dynamic>)
            : null,
        lastVisitedAt: json['lastVisitedAt'] != null
            ? DateTime.tryParse(json['lastVisitedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  NoteFile copyWith({
    String? title,
    String? content,
    String? folderId,
    int? colorValue,
    NoteReminder? reminder,
    DateTime? lastVisitedAt,
    DateTime? updatedAt,
    bool clearReminder = false,
    bool clearFolder = false,
    bool clearLastVisited = false,
  }) =>
      NoteFile(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        colorValue: colorValue ?? this.colorValue,
        reminder: clearReminder ? null : (reminder ?? this.reminder),
        lastVisitedAt:
            clearLastVisited ? null : (lastVisitedAt ?? this.lastVisitedAt),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
