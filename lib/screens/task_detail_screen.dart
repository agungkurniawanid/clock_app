import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../widgets/status_badge.dart';
import '../theme/app_colors.dart';
import 'add_task_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    final surface = isDark ? darkSurface : lightSurface;
    final card = isDark ? darkCard : lightCard;
    final primary = Theme.of(context).colorScheme.primary;

    // Watch latest version of task
    final latestTask = ref.watch(taskListProvider).firstWhere(
          (t) => t.id == task.id,
          orElse: () => task,
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? darkBackground : lightBackground,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      latestTask.colorTag.withValues(alpha: 0.3),
                      latestTask.colorTag.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: latestTask.status, large: true),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _categoryColor(latestTask.category)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _categoryColor(latestTask.category)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                latestTask.categoryLabel,
                                style: TextStyle(
                                    color: _categoryColor(latestTask.category),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _priorityBadge(context, latestTask.priority),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          latestTask.title,
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '${_formatDate(latestTask.date)} • ${latestTask.timeLabel}',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  _sectionCard(
                    context,
                    card,
                    icon: Icons.description_rounded,
                    title: 'Description',
                    child: Text(
                      latestTask.description,
                      style: TextStyle(
                          color: textPrimary, fontSize: 14, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Schedule
                  _sectionCard(
                    context,
                    card,
                    icon: Icons.event_rounded,
                    title: 'Schedule',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(context, Icons.calendar_today_rounded,
                            _formatDate(latestTask.date), textSecondary),
                        const SizedBox(height: 6),
                        _detailRow(context, Icons.access_time_rounded,
                            latestTask.timeLabel, textSecondary),
                        const SizedBox(height: 6),
                        _detailRow(context, Icons.repeat_rounded,
                            'Repeat: ${latestTask.repeatLabel}', textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reminders
                  if (latestTask.reminders.isNotEmpty)
                    _sectionCard(
                      context,
                      card,
                      icon: Icons.notifications_rounded,
                      title: 'Reminders',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: latestTask.reminders
                            .map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle,
                                          size: 6, color: primary),
                                      const SizedBox(width: 10),
                                      Text(r,
                                          style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  if (latestTask.reminders.isNotEmpty)
                    const SizedBox(height: 12),

                  // Alarm Mode
                  _sectionCard(
                    context,
                    card,
                    icon: Icons.alarm_rounded,
                    title: 'Alarm Mode',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                          context,
                          latestTask.alarmMode == AlarmMode.alarmMusic
                              ? Icons.music_note_rounded
                              : Icons.notifications_rounded,
                          latestTask.alarmMode == AlarmMode.alarmMusic
                              ? 'Music Alarm'
                              : 'Notification Only',
                          textSecondary,
                        ),
                        if (latestTask.musicFile != null) ...[
                          const SizedBox(height: 6),
                          _detailRow(context, Icons.audio_file_rounded,
                              'Music: ${latestTask.musicFile}', textSecondary),
                          const SizedBox(height: 6),
                          _detailRow(context, Icons.volume_up_rounded,
                              'Volume: ${latestTask.volume}%', textSecondary),
                          const SizedBox(height: 6),
                          _detailRow(
                              context,
                              Icons.snooze_rounded,
                              'Snooze: ${latestTask.snoozeMinutes} min',
                              textSecondary),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // History
                  if (latestTask.history.isNotEmpty)
                    _sectionCard(
                      context,
                      card,
                      icon: Icons.history_rounded,
                      title: 'History',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: latestTask.history
                            .map((h) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_filled_rounded,
                                          size: 14, color: textSecondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(h,
                                            style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            top: BorderSide(color: textSecondary!.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTaskScreen(editTask: latestTask),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: latestTask.status == TaskStatus.completed
                    ? null
                    : () {
                        ref
                            .read(taskListProvider.notifier)
                            .markComplete(latestTask.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Task marked as completed!')),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusCompleted,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Mark Complete'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                ref.read(taskListProvider.notifier).deleteTask(latestTask.id);
                Navigator.pop(context);
              },
              style: IconButton.styleFrom(
                backgroundColor: statusOverdue.withValues(alpha: 0.1),
                foregroundColor: statusOverdue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, Color bg,
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, Color? color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 13)),
      ],
    );
  }

  Color _categoryColor(TaskCategory c) {
    switch (c) {
      case TaskCategory.work:
        return categoryWork;
      case TaskCategory.personal:
        return categoryPersonal;
      case TaskCategory.health:
        return categoryHealth;
      case TaskCategory.study:
        return categoryStudy;
      case TaskCategory.other:
        return categoryOther;
    }
  }

  Widget _priorityBadge(BuildContext context, TaskPriority p) {
    Color color;
    switch (p) {
      case TaskPriority.low:
        color = priorityLow;
        break;
      case TaskPriority.medium:
        color = priorityMedium;
        break;
      case TaskPriority.high:
        color = priorityHigh;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(p.name.toUpperCase().substring(0, 1) + p.name.substring(1),
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
