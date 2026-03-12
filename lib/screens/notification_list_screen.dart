import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_item.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import 'task_detail_screen.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when the screen opens so the badge clears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationListProvider);
    final tasks = ref.watch(taskListProvider);

    // Sort newest first
    final sorted = [...notifications]
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

    return Scaffold(
      backgroundColor: isDark ? darkBackground : lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? darkBackground : lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          if (sorted.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).markAllRead(),
              child: Text(
                'Mark All as Read',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: sorted.isEmpty
          ? _buildEmpty(context, isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final item = sorted[index];
                final task = tasks.firstWhere(
                  (t) => t.id == item.taskId,
                  orElse: () => _deletedTask(item),
                );
                return _NotificationTile(
                  item: item,
                  task: task,
                  onTap: () => _openTaskDetail(context, item, task),
                  onDismiss: () => ref
                      .read(notificationListProvider.notifier)
                      .dismissById(item.id),
                );
              },
            ),
    );
  }

  void _openTaskDetail(
      BuildContext context, NotificationItem item, TaskModel task) {
    ref.read(notificationListProvider.notifier).markReadByTaskId(item.taskId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Task notifications that have triggered\nwill appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }

  /// Fallback task object when the original task has been deleted.
  TaskModel _deletedTask(NotificationItem item) {
    return TaskModel(
      id: item.taskId,
      title: item.taskTitle,
      description: item.taskDescription,
      category: item.taskCategory,
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      date: item.triggeredAt,
      time: TimeOfDay(
          hour: item.triggeredAt.hour, minute: item.triggeredAt.minute),
      alarmMode: item.alarmMode,
      volume: 100,
      snoozeMinutes: 15,
      repeat: RepeatType.none,
      weekDays: const [false, true, true, true, true, true, false],
      reminders: const [],
      colorTag: const Color(0xFF7B6EF6),
      history: const [],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.item,
    required this.task,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !item.isRead;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: statusOverdue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: statusOverdue, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUnread
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.15),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/icon-launcher-2-transparent.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.taskTitle,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w600,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (item.taskDescription.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.taskDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeLabel(item.triggeredAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: 10),
                        _ModeBadge(alarmMode: item.alarmMode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';

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
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $h:$m';
  }
}

class _ModeBadge extends StatelessWidget {
  final AlarmMode alarmMode;
  const _ModeBadge({required this.alarmMode});

  @override
  Widget build(BuildContext context) {
    final isAlarm = alarmMode == AlarmMode.alarmMusic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAlarm
            ? statusRisk.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAlarm ? 'Alarm' : 'Notification',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isAlarm ? statusRisk : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
