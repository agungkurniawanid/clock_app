import '../models/task_model.dart';

/// Represents a single in-app notification entry.
///
/// An entry is created when a task reaches its scheduled start time.
/// It stays unread until the user views the task's detail screen.
class NotificationItem {
  final String id;
  final String taskId;
  final String taskTitle;
  final String taskDescription;
  final TaskCategory taskCategory;
  final AlarmMode alarmMode;
  final DateTime triggeredAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskCategory,
    required this.alarmMode,
    required this.triggeredAt,
    this.isRead = false,
  });

  factory NotificationItem.fromTask(TaskModel task) {
    final startDt = DateTime(
      task.date.year,
      task.date.month,
      task.date.day,
      task.time.hour,
      task.time.minute,
    );
    return NotificationItem(
      id: 'notif_${task.id}',
      taskId: task.id,
      taskTitle: task.title,
      taskDescription: task.description,
      taskCategory: task.category,
      alarmMode: task.alarmMode,
      triggeredAt: startDt,
      isRead: false,
    );
  }

  NotificationItem copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    String? taskDescription,
    TaskCategory? taskCategory,
    AlarmMode? alarmMode,
    DateTime? triggeredAt,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      taskDescription: taskDescription ?? this.taskDescription,
      taskCategory: taskCategory ?? this.taskCategory,
      alarmMode: alarmMode ?? this.alarmMode,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'taskDescription': taskDescription,
        'taskCategory': taskCategory.index,
        'alarmMode': alarmMode.index,
        'triggeredAt': triggeredAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      taskTitle: json['taskTitle'] as String,
      taskDescription: (json['taskDescription'] as String?) ?? '',
      taskCategory: TaskCategory.values[(json['taskCategory'] as int)
          .clamp(0, TaskCategory.values.length - 1)],
      alarmMode: AlarmMode.values[
          (json['alarmMode'] as int).clamp(0, AlarmMode.values.length - 1)],
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }
}
