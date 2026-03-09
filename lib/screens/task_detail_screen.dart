import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../services/audio_service.dart';
import '../widgets/status_badge.dart';
import '../theme/app_colors.dart';
import '../utils/app_toast.dart';
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
                  // Checklist & Sub-tasks
                  if (latestTask.checklist.isNotEmpty ||
                      latestTask.subTasks.isNotEmpty) ...[
                    _sectionCard(
                      context,
                      card,
                      icon: Icons.checklist_rounded,
                      title: _checklistSectionTitle(latestTask),
                      child: _buildChecklistContent(context, latestTask, ref,
                          textPrimary, textSecondary, primary),
                    ),
                    const SizedBox(height: 12),
                  ],

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

                  // Start Date & Alarm
                  _sectionCard(
                    context,
                    card,
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Start Date & Alarm',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                            context,
                            Icons.calendar_today_rounded,
                            'Start: ${_formatDate(latestTask.date)}',
                            textSecondary),
                        const SizedBox(height: 6),
                        _detailRow(context, Icons.access_time_rounded,
                            'Time: ${latestTask.timeLabel}', textSecondary),
                        const SizedBox(height: 6),
                        _detailRow(context, Icons.repeat_rounded,
                            'Repeat: ${latestTask.repeatLabel}', textSecondary),
                        const SizedBox(height: 10),
                        _detailRow(
                          context,
                          latestTask.alarmMode == AlarmMode.alarmMusic
                              ? Icons.music_note_rounded
                              : Icons.notifications_rounded,
                          latestTask.alarmMode == AlarmMode.alarmMusic
                              ? 'Alarm: Music'
                              : 'Alarm: Notification Only',
                          textSecondary,
                        ),
                        if (latestTask.musicFile != null) ...[
                          const SizedBox(height: 6),
                          _detailRow(
                              context,
                              Icons.audio_file_rounded,
                              'Music: ${_cleanMusicName(latestTask.musicFile!)}',
                              textSecondary),
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
                        if (latestTask.reminders.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.notifications_rounded,
                                  size: 15, color: textSecondary),
                              const SizedBox(width: 8),
                              Text('Reminders:',
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...latestTask.reminders.map((r) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 23, bottom: 4),
                                child: Row(children: [
                                  Icon(Icons.circle, size: 5, color: primary),
                                  const SizedBox(width: 8),
                                  Text(r,
                                      style: TextStyle(
                                          color: textPrimary, fontSize: 13)),
                                ]),
                              )),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Due Date & Reminders
                  if (latestTask.dueDateEnabled && latestTask.dueDate != null)
                    _sectionCard(
                      context,
                      card,
                      icon: Icons.flag_rounded,
                      title: 'Due Date & Reminders',
                      iconColor: Theme.of(context).colorScheme.secondary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(
                              context,
                              Icons.flag_rounded,
                              'Due: ${_formatDate(latestTask.dueDate!)}',
                              textSecondary),
                          if (latestTask.dueTime != null) ...[
                            const SizedBox(height: 6),
                            _detailRow(
                                context,
                                Icons.access_time_rounded,
                                'Time: ${latestTask.dueTimeLabel}',
                                textSecondary),
                          ],
                          if (latestTask.dueReminderEnabled &&
                              latestTask.dueReminders.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.notifications_active_rounded,
                                    size: 15, color: textSecondary),
                                const SizedBox(width: 8),
                                Text('Due Reminders:',
                                    style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...latestTask.dueReminders.map((r) => Padding(
                                  padding: const EdgeInsets.only(
                                      left: 23, bottom: 4),
                                  child: Row(children: [
                                    Icon(Icons.circle,
                                        size: 5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary),
                                    const SizedBox(width: 8),
                                    Text(r,
                                        style: TextStyle(
                                            color: textPrimary, fontSize: 13)),
                                  ]),
                                )),
                            const SizedBox(height: 8),
                            _detailRow(
                              context,
                              latestTask.dueAlarmMode == AlarmMode.alarmMusic
                                  ? Icons.music_note_rounded
                                  : Icons.notifications_rounded,
                              latestTask.dueAlarmMode == AlarmMode.alarmMusic
                                  ? 'Reminder Alarm: Music'
                                  : 'Reminder Alarm: Notification Only',
                              textSecondary,
                            ),
                            if (latestTask.dueMusicFile != null) ...[
                              const SizedBox(height: 6),
                              _detailRow(
                                  context,
                                  Icons.audio_file_rounded,
                                  'Music: ${_cleanMusicName(latestTask.dueMusicFile!)}',
                                  textSecondary),
                              const SizedBox(height: 6),
                              _detailRow(
                                  context,
                                  Icons.volume_up_rounded,
                                  'Volume: ${latestTask.dueVolume}%',
                                  textSecondary),
                            ],
                          ],
                        ],
                      ),
                    ),
                  if (latestTask.dueDateEnabled && latestTask.dueDate != null)
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
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text(
                  'Edit',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
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
                        AppToast.show(
                          context,
                          'Task marked as completed!',
                          type: ToastType.success,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Checklist & Sub-tasks helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _checklistSectionTitle(TaskModel task) {
    final total = task.checklist.length +
        task.subTasks.length +
        task.subTasks.fold(0, (s, st) => s + st.checklist.length);
    int done = task.checklist.where((c) => c.isChecked).length +
        task.subTasks.where((st) => st.isChecked).length;
    for (final st in task.subTasks) {
      done += st.checklist.where((c) => c.isChecked).length;
    }
    if (total == 0) return 'Checklist & Sub-tasks';
    return 'Checklist & Sub-tasks ($done/$total)';
  }

  Widget _buildChecklistContent(
    BuildContext context,
    TaskModel task,
    WidgetRef ref,
    Color? textPrimary,
    Color? textSecondary,
    Color primary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flat checklist items
        if (task.checklist.isNotEmpty) ...[
          ...task.checklist.map((item) => _checklistItemTile(
                context,
                item.title,
                item.isChecked,
                textPrimary,
                primary,
                onToggle: () {
                  final updated = task.copyWith(
                    checklist: task.checklist
                        .map((c) => c.id == item.id
                            ? c.copyWith(isChecked: !c.isChecked)
                            : c)
                        .toList(),
                  );
                  ref.read(taskListProvider.notifier).updateTask(updated);
                },
              )),
          if (task.subTasks.isNotEmpty) const SizedBox(height: 8),
        ],

        // Sub-tasks
        ...task.subTasks.map((st) => _buildSubTaskDisplay(
              context,
              task,
              st,
              ref,
              textPrimary,
              textSecondary,
              primary,
            )),
      ],
    );
  }

  Widget _buildSubTaskDisplay(
    BuildContext context,
    TaskModel task,
    SubTask st,
    WidgetRef ref,
    Color? textPrimary,
    Color? textSecondary,
    Color primary,
  ) {
    final hasChildren = st.checklist.isNotEmpty || st.subTasks.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: hasChildren
          ? Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 16, bottom: 6),
                leading: Checkbox(
                  value: st.isChecked,
                  activeColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) {
                    final updated = task.copyWith(
                        subTasks: _toggleSubTaskInTree(task.subTasks, st.id));
                    ref.read(taskListProvider.notifier).updateTask(updated);
                  },
                ),
                title: Text(
                  st.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration:
                        st.isChecked ? TextDecoration.lineThrough : null,
                    decorationColor: textPrimary?.withValues(alpha: 0.5),
                  ),
                ),
                iconColor: textSecondary,
                collapsedIconColor: textSecondary,
                children: [
                  // Nested checklist items
                  if (st.checklist.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.checklist_rounded,
                            size: 12, color: textSecondary),
                        const SizedBox(width: 6),
                        Text('Checklist',
                            style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    ...st.checklist.map((c) => _checklistItemTile(
                          context,
                          c.title,
                          c.isChecked,
                          textPrimary,
                          primary,
                          compact: true,
                          onToggle: () {
                            final updated = task.copyWith(
                                subTasks: _toggleChecklistInTree(
                                    task.subTasks, st.id, c.id));
                            ref
                                .read(taskListProvider.notifier)
                                .updateTask(updated);
                          },
                        )),
                    if (st.subTasks.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // Nested sub-tasks
                  if (st.subTasks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.account_tree_rounded,
                            size: 12, color: textSecondary),
                        const SizedBox(width: 6),
                        Text('Sub-tasks',
                            style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    ...st.subTasks.map((child) => _buildSubTaskDisplay(
                          context,
                          task,
                          child,
                          ref,
                          textPrimary,
                          textSecondary,
                          primary,
                        )),
                  ],
                ],
              ),
            )
          : _checklistItemTile(
              context,
              st.title,
              st.isChecked,
              textPrimary,
              primary,
              isSubTask: true,
              onToggle: () {
                final updated = task.copyWith(
                    subTasks: _toggleSubTaskInTree(task.subTasks, st.id));
                ref.read(taskListProvider.notifier).updateTask(updated);
              },
            ),
    );
  }

  Widget _checklistItemTile(
    BuildContext context,
    String title,
    bool isChecked,
    Color? textPrimary,
    Color primary, {
    VoidCallback? onToggle,
    bool compact = false,
    bool isSubTask = false,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 28 : 32,
              height: compact ? 28 : 32,
              child: Checkbox(
                value: isChecked,
                activeColor: primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isSubTask ? 6 : 4)),
                onChanged: onToggle != null ? (_) => onToggle() : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isChecked
                      ? textPrimary?.withValues(alpha: 0.45)
                      : textPrimary,
                  fontSize: compact ? 12 : 14,
                  fontWeight: isSubTask ? FontWeight.w600 : FontWeight.w400,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: textPrimary?.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tree toggle helpers ─────────────────────────────────────────────────
  List<SubTask> _toggleSubTaskInTree(List<SubTask> tasks, String targetId) =>
      tasks
          .map((t) => t.id == targetId
              ? t.copyWith(isChecked: !t.isChecked)
              : t.copyWith(
                  subTasks: _toggleSubTaskInTree(t.subTasks, targetId)))
          .toList();

  List<SubTask> _toggleChecklistInTree(
          List<SubTask> tasks, String subTaskId, String checklistId) =>
      tasks.map((t) {
        if (t.id == subTaskId) {
          return t.copyWith(
            checklist: t.checklist
                .map((c) => c.id == checklistId
                    ? c.copyWith(isChecked: !c.isChecked)
                    : c)
                .toList(),
          );
        }
        return t.copyWith(
            subTasks:
                _toggleChecklistInTree(t.subTasks, subTaskId, checklistId));
      }).toList();

  Widget _sectionCard(BuildContext context, Color bg,
      {required IconData icon,
      required String title,
      required Widget child,
      Color? iconColor}) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
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
              Icon(icon, size: 18, color: color),
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

  String _cleanMusicName(String file) {
    return AudioService.displayName(file)
        .replaceAll('_', ' ')
        .replaceAll('.mp3', '')
        .replaceAll('.m4a', '')
        .replaceAll('.ogg', '')
        .replaceAll('.wav', '');
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
