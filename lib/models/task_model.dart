import 'package:flutter/material.dart';

enum TaskStatus { todo, inProgress, risk, overdue, completed, upcoming }

enum AlarmMode { notificationOnly, alarmMusic }

enum RepeatType { none, daily, weekly, monthly, custom }

enum TaskPriority { low, medium, high }

enum TaskCategory { work, personal, health, study, other }

// ── Checklist Item ────────────────────────────────────────────────────────────
class ChecklistItem {
  final String id;
  final String title;
  final bool isChecked;

  const ChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  ChecklistItem copyWith({
    String? id,
    String? title,
    bool? isChecked,
  }) =>
      ChecklistItem(
        id: id ?? this.id,
        title: title ?? this.title,
        isChecked: isChecked ?? this.isChecked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isChecked': isChecked,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
    );
  }
}

// ── Sub-task (has all TaskModel fields) ───────────────────────────────────────
class SubTask {
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
  final List<bool> weekDays;

  // ── Custom Repeat ──────────────────────────────────────────────────────────
  final int customInterval;
  final String customIntervalUnit;
  final String customEndType;
  final DateTime? customEndDate;
  final int customEndAfterCount;
  final List<bool> customWeekDays;

  final List<String> reminders;
  final Color colorTag;

  // ── Checklist & Nested Sub-tasks ───────────────────────────────────────────
  final List<ChecklistItem> checklist;
  final List<SubTask> subTasks;

  /// When true, subtask status automatically changes to completed
  /// once every checklist item is checked.
  final bool autoCompleteOnChecklist;

  const SubTask({
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
    this.customInterval = 1,
    this.customIntervalUnit = 'Days',
    this.customEndType = 'Never',
    this.customEndDate,
    this.customEndAfterCount = 1,
    this.customWeekDays = const [false, false, false, false, false, false, false],
    required this.reminders,
    required this.colorTag,
    this.checklist = const [],
    this.subTasks = const [],
    this.autoCompleteOnChecklist = false,
  });

  SubTask copyWith({
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
    int? customInterval,
    String? customIntervalUnit,
    String? customEndType,
    DateTime? customEndDate,
    bool clearCustomEndDate = false,
    int? customEndAfterCount,
    List<bool>? customWeekDays,
    List<String>? reminders,
    Color? colorTag,
    List<ChecklistItem>? checklist,
    List<SubTask>? subTasks,
    bool? autoCompleteOnChecklist,
  }) =>
      SubTask(
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
        customInterval: customInterval ?? this.customInterval,
        customIntervalUnit: customIntervalUnit ?? this.customIntervalUnit,
        customEndType: customEndType ?? this.customEndType,
        customEndDate: clearCustomEndDate ? null : (customEndDate ?? this.customEndDate),
        customEndAfterCount: customEndAfterCount ?? this.customEndAfterCount,
        customWeekDays: customWeekDays ?? this.customWeekDays,
        reminders: reminders ?? this.reminders,
        colorTag: colorTag ?? this.colorTag,
        checklist: checklist ?? this.checklist,
        subTasks: subTasks ?? this.subTasks,
        autoCompleteOnChecklist: autoCompleteOnChecklist ?? this.autoCompleteOnChecklist,
      );

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
        'customInterval': customInterval,
        'customIntervalUnit': customIntervalUnit,
        'customEndType': customEndType,
        'customEndDate': customEndDate?.toIso8601String(),
        'customEndAfterCount': customEndAfterCount,
        'customWeekDays': customWeekDays,
        'reminders': reminders,
        'colorTag': colorTag.toARGB32(),
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'subTasks': subTasks.map((s) => s.toJson()).toList(),
        'autoCompleteOnChecklist': autoCompleteOnChecklist,
      };

  factory SubTask.fromJson(Map<String, dynamic> json) {
    TimeOfDay? dueTime;
    if (json['dueTime_hour'] != null && json['dueTime_minute'] != null) {
      dueTime = TimeOfDay(
        hour: json['dueTime_hour'] as int,
        minute: json['dueTime_minute'] as int,
      );
    }

    return SubTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TaskCategory.values[(json['category'] as int? ?? 0).clamp(0, TaskCategory.values.length - 1)],
      status: TaskStatus.values[(json['status'] as int? ?? 0).clamp(0, TaskStatus.values.length - 1)],
      priority: TaskPriority.values[(json['priority'] as int? ?? 0).clamp(0, TaskPriority.values.length - 1)],
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      time: json['time_hour'] != null && json['time_minute'] != null
          ? TimeOfDay(hour: json['time_hour'] as int, minute: json['time_minute'] as int)
          : TimeOfDay.now(),
      alarmMode: AlarmMode.values[(json['alarmMode'] as int? ?? 0).clamp(0, AlarmMode.values.length - 1)],
      musicFile: json['musicFile'] as String?,
      volume: json['volume'] as int? ?? 100,
      snoozeMinutes: json['snoozeMinutes'] as int? ?? 15,
      dueDateEnabled: json['dueDateEnabled'] as bool? ?? false,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      dueTime: dueTime,
      dueReminderEnabled: json['dueReminderEnabled'] as bool? ?? false,
      dueReminders: (json['dueReminders'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      dueAlarmMode: AlarmMode.values[(json['dueAlarmMode'] as int? ?? 0).clamp(0, AlarmMode.values.length - 1)],
      dueMusicFile: json['dueMusicFile'] as String?,
      dueVolume: json['dueVolume'] as int? ?? 100,
      dueSnoozeMinutes: json['dueSnoozeMinutes'] as int? ?? 15,
      repeat: RepeatType.values[(json['repeat'] as int? ?? 0).clamp(0, RepeatType.values.length - 1)],
      weekDays: (json['weekDays'] as List<dynamic>?)?.map((e) => e as bool).toList() ?? List.filled(7, false),
      customInterval: json['customInterval'] as int? ?? 1,
      customIntervalUnit: json['customIntervalUnit'] as String? ?? 'Days',
      customEndType: json['customEndType'] as String? ?? 'Never',
      customEndDate: json['customEndDate'] != null ? DateTime.parse(json['customEndDate'] as String) : null,
      customEndAfterCount: json['customEndAfterCount'] as int? ?? 1,
      customWeekDays: (json['customWeekDays'] as List<dynamic>?)?.map((e) => e as bool).toList() ?? List.filled(7, false),
      reminders: (json['reminders'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      colorTag: Color(json['colorTag'] as int? ?? 0xFF2196F3),
      checklist: (json['checklist'] as List<dynamic>?)?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      subTasks: (json['subTasks'] as List<dynamic>?)?.map((e) => SubTask.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      autoCompleteOnChecklist: json['autoCompleteOnChecklist'] as bool? ?? false,
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dueDate!.day} ${months[dueDate!.month - 1]} ${dueDate!.year}';
  }

  String? get dueTimeLabel {
    if (dueTime == null) return null;
    final h = dueTime!.hour.toString().padLeft(2, '0');
    final m = dueTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Check if subtask can be completed ─────────────────────────────────────
  /// Subtask can only be marked completed if it has no checklist
  /// or all checklist items are completed, AND all nested subtasks are completed
  bool get canBeCompleted {
    // Check if all direct checklist items are completed
    if (checklist.isNotEmpty && !checklist.every((item) => item.isChecked)) {
      return false;
    }
    // Check if all nested subtasks are completed
    if (subTasks.isNotEmpty && !subTasks.every((st) => st.status == TaskStatus.completed)) {
      return false;
    }
    return true;
  }

  // ── Checklist progress (recursive) ────────────────────────────────────────
  /// Total checklist items = this subtask's checklist + all nested subtasks' checklists
  int get totalChecklistItems =>
      checklist.length +
      subTasks.fold(0, (sum, st) => sum + st.totalChecklistItems);

  int get completedChecklistItems =>
      checklist.where((c) => c.isChecked).length +
      subTasks.fold(0, (sum, st) => sum + st.completedChecklistItems);
}

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
  final List<bool> weekDays; // Sun–Sat (used for RepeatType.weekly)

  // ── Custom Repeat ──────────────────────────────────────────────────────────
  final int customInterval; // e.g. 2
  final String customIntervalUnit; // 'Days' | 'Weeks' | 'Months' | 'Years'
  final String customEndType; // 'Never' | 'On Date' | 'After'
  final DateTime? customEndDate; // used when customEndType == 'On Date'
  final int customEndAfterCount; // used when customEndType == 'After'
  final List<bool>
      customWeekDays; // Sun–Sat, used when customIntervalUnit == 'Weeks'

  final List<String> reminders; // start date reminders
  final Color colorTag;
  final List<String> history;

  // ── Checklist & Sub-tasks ──────────────────────────────────────────────────
  final List<ChecklistItem> checklist;
  final List<SubTask> subTasks;

  /// When true, task status automatically changes to [TaskStatus.completed]
  /// once every checklist item and sub-task is checked.
  final bool autoCompleteOnChecklist;

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
    this.customInterval = 1,
    this.customIntervalUnit = 'Days',
    this.customEndType = 'Never',
    this.customEndDate,
    this.customEndAfterCount = 1,
    this.customWeekDays = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false
    ],
    required this.reminders,
    required this.colorTag,
    required this.history,
    this.checklist = const [],
    this.subTasks = const [],
    this.autoCompleteOnChecklist = false,
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
        'customInterval': customInterval,
        'customIntervalUnit': customIntervalUnit,
        'customEndType': customEndType,
        'customEndDate': customEndDate?.toIso8601String(),
        'customEndAfterCount': customEndAfterCount,
        'customWeekDays': customWeekDays,
        'reminders': reminders,
        'colorTag': colorTag.toARGB32(),
        'history': history,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'subTasks': subTasks.map((s) => s.toJson()).toList(),
        'autoCompleteOnChecklist': autoCompleteOnChecklist,
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
      customInterval: json['customInterval'] as int? ?? 1,
      customIntervalUnit: json['customIntervalUnit'] as String? ?? 'Days',
      customEndType: json['customEndType'] as String? ?? 'Never',
      customEndDate: json['customEndDate'] != null
          ? DateTime.parse(json['customEndDate'] as String)
          : null,
      customEndAfterCount: json['customEndAfterCount'] as int? ?? 1,
      customWeekDays: json['customWeekDays'] != null
          ? (json['customWeekDays'] as List<dynamic>)
              .map((e) => e as bool)
              .toList()
          : List.filled(7, false),
      reminders:
          (json['reminders'] as List<dynamic>).map((e) => e as String).toList(),
      colorTag: Color(json['colorTag'] as int),
      history:
          (json['history'] as List<dynamic>).map((e) => e as String).toList(),
      checklist: (json['checklist'] as List<dynamic>?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((e) => SubTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      autoCompleteOnChecklist:
          json['autoCompleteOnChecklist'] as bool? ?? false,
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
    int? customInterval,
    String? customIntervalUnit,
    String? customEndType,
    DateTime? customEndDate,
    bool clearCustomEndDate = false,
    int? customEndAfterCount,
    List<bool>? customWeekDays,
    List<String>? reminders,
    Color? colorTag,
    List<String>? history,
    List<ChecklistItem>? checklist,
    List<SubTask>? subTasks,
    bool? autoCompleteOnChecklist,
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
      customInterval: customInterval ?? this.customInterval,
      customIntervalUnit: customIntervalUnit ?? this.customIntervalUnit,
      customEndType: customEndType ?? this.customEndType,
      customEndDate:
          clearCustomEndDate ? null : (customEndDate ?? this.customEndDate),
      customEndAfterCount: customEndAfterCount ?? this.customEndAfterCount,
      customWeekDays: customWeekDays ?? this.customWeekDays,
      reminders: reminders ?? this.reminders,
      colorTag: colorTag ?? this.colorTag,
      history: history ?? this.history,
      checklist: checklist ?? this.checklist,
      subTasks: subTasks ?? this.subTasks,
      autoCompleteOnChecklist:
          autoCompleteOnChecklist ?? this.autoCompleteOnChecklist,
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

  // ── Repeat occurrence check ───────────────────────────────────────────────
  /// Returns true if this task should appear on [date] based on repeat settings.
  /// Completed tasks only match their exact start date.
  bool occursOnDate(DateTime date) {
    final taskStart = DateUtils.dateOnly(this.date);
    final checkDate = DateUtils.dateOnly(date);

    if (checkDate.isBefore(taskStart)) return false;

    // Completed tasks don't generate future recurrences
    if (status == TaskStatus.completed) {
      return checkDate == taskStart;
    }

    switch (repeat) {
      case RepeatType.none:
        return checkDate == taskStart;
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        final anySelected = weekDays.any((d) => d);
        if (!anySelected) {
          // fallback: same weekday as task start
          return checkDate.weekday == taskStart.weekday;
        }
        // weekDays is [Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6]
        // DateTime.weekday: Mon=1..Sun=7 → convert: Sun=7%7=0, Mon..Sat=1..6
        final dayIndex = checkDate.weekday % 7;
        return weekDays[dayIndex];
      case RepeatType.monthly:
        return checkDate.day == taskStart.day;
      case RepeatType.custom:
        final daysDiff = checkDate.difference(taskStart).inDays;

        // Check 'On Date' end condition
        if (customEndType == 'On Date' && customEndDate != null) {
          final endDate = DateUtils.dateOnly(customEndDate!);
          if (checkDate.isAfter(endDate)) return false;
        }

        // Determine if checkDate matches the recurrence pattern
        bool occurs;
        switch (customIntervalUnit) {
          case 'Days':
            occurs = daysDiff % customInterval == 0;
            break;
          case 'Weeks':
            final weeksDiff = daysDiff ~/ 7;
            final hasSelectedDays = customWeekDays.any((d) => d);
            if (hasSelectedDays) {
              final dayIndex = checkDate.weekday % 7; // Sun=0..Sat=6
              occurs =
                  weeksDiff % customInterval == 0 && customWeekDays[dayIndex];
            } else {
              occurs = daysDiff % (customInterval * 7) == 0;
            }
            break;
          case 'Months':
            final monthsDiff = (checkDate.year - taskStart.year) * 12 +
                (checkDate.month - taskStart.month);
            occurs = monthsDiff >= 0 &&
                monthsDiff % customInterval == 0 &&
                checkDate.day == taskStart.day;
            break;
          case 'Years':
            final yearsDiff = checkDate.year - taskStart.year;
            occurs = yearsDiff >= 0 &&
                yearsDiff % customInterval == 0 &&
                checkDate.month == taskStart.month &&
                checkDate.day == taskStart.day;
            break;
          default:
            occurs = daysDiff % customInterval == 0;
        }

        if (!occurs) return false;

        // Check 'After N occurrences' end condition
        if (customEndType == 'After') {
          int occurrenceIndex;
          switch (customIntervalUnit) {
            case 'Days':
              occurrenceIndex = daysDiff ~/ customInterval + 1;
              break;
            case 'Weeks':
              final weeksDiff2 = daysDiff ~/ 7;
              occurrenceIndex = weeksDiff2 ~/ customInterval + 1;
              break;
            case 'Months':
              final monthsDiff2 = (checkDate.year - taskStart.year) * 12 +
                  (checkDate.month - taskStart.month);
              occurrenceIndex = monthsDiff2 ~/ customInterval + 1;
              break;
            case 'Years':
              final yearsDiff2 = checkDate.year - taskStart.year;
              occurrenceIndex = yearsDiff2 ~/ customInterval + 1;
              break;
            default:
              occurrenceIndex = daysDiff ~/ customInterval + 1;
          }
          if (occurrenceIndex > customEndAfterCount) return false;
        }

        return true;
    }
  }

  // ── Checklist progress ────────────────────────────────────────────────────
  /// Grand total = task's checklist + all subtasks' checklists (recursively) combined
  int get totalChecklistItems =>
      checklist.length +
      subTasks.fold(0, (sum, st) => sum + st.totalChecklistItems);

  int get completedChecklistItems =>
      checklist.where((c) => c.isChecked).length +
      subTasks.fold(0, (sum, st) => sum + st.completedChecklistItems);
}
