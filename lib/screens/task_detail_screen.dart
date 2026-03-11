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

class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Mark the in-app notification for this task as read when the detail opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(notificationListProvider.notifier)
          .markReadByTaskId(widget.task.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    final surface = isDark ? darkSurface : lightSurface;
    final card = isDark ? darkCard : lightCard;
    final primary = Theme.of(context).colorScheme.primary;

    // Watch latest version of task
    final latestTask = ref.watch(taskListProvider).firstWhere(
          (t) => t.id == widget.task.id,
          orElse: () => widget.task,
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
    // Grand total = task's checklist + all subtasks' checklists combined
    final total = task.totalChecklistItems;
    final done = task.completedChecklistItems;

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
    final allDone = task.totalChecklistItems > 0 &&
        task.completedChecklistItems == task.totalChecklistItems;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = primary.withValues(alpha: 0.28);
    final totalItems = task.checklist.length + task.subTasks.length;
    var idx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── All-done badge ──────────────────────────────────────────────
        if (allDone) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 18, color: Color(0xFF22C55E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.autoCompleteOnChecklist
                        ? 'Semua checklist selesai! Task otomatis Completed.'
                        : 'Semua checklist & sub-task sudah selesai!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Progress bar ──────────────────────────────────────────────
        if (task.totalChecklistItems > 0) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        task.completedChecklistItems / task.totalChecklistItems,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    color: allDone ? const Color(0xFF22C55E) : primary,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${task.completedChecklistItems}/${task.totalChecklistItems}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: allDone ? const Color(0xFF22C55E) : primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // ── Flat checklist items (tree style) ────────────────────────
        ...List<Widget>.generate(task.checklist.length, (i) {
          final item = task.checklist[i];
          idx++;
          final isLast = idx == totalItems;
          return _treeItemRow(
            isLast: isLast,
            lineColor: lineColor,
            child: _checklistItemContent(
              context: context,
              item: item,
              textPrimary: textPrimary,
              primary: primary,
              textSecondary: textSecondary,
              onToggle: () {
                final updated = task.copyWith(
                  checklist: task.checklist
                      .map((c) => c.id == item.id
                          ? c.copyWith(isChecked: !c.isChecked)
                          : c)
                      .toList(),
                );
                _handleChecklistUpdate(context, updated, ref);
              },
            ),
          );
        }),

        // ── Sub-tasks (tree style) ────────────────────────────────────
        ...List<Widget>.generate(task.subTasks.length, (i) {
          final st = task.subTasks[i];
          idx++;
          final isLast = idx == totalItems;
          return _treeSubTaskRow(
            context: context,
            task: task,
            st: st,
            ref: ref,
            isLast: isLast,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            primary: primary,
            lineColor: lineColor,
          );
        }),
      ],
    );
  }

  // ── Tree-line design helpers ─────────────────────────────────────────────

  /// Draws a ├── or └── tree connector on the left, then renders [child].
  Widget _treeItemRow({
    required Widget child,
    required bool isLast,
    required Color lineColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree line column (22 px wide)
          SizedBox(
            width: 22,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Vertical: top segment to the connector point
                Positioned(
                  left: 9,
                  top: 0,
                  child: Container(width: 1.5, height: 22, color: lineColor),
                ),
                // Vertical: continuation line to next sibling
                if (!isLast)
                  Positioned(
                    left: 9,
                    top: 22,
                    bottom: 0,
                    child: Container(width: 1.5, color: lineColor),
                  ),
                // Horizontal: connector ─────
                Positioned(
                  left: 9,
                  top: 21,
                  right: 0,
                  child: Container(height: 1.5, color: lineColor),
                ),
              ],
            ),
          ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Checklist leaf item rendered inside a tree node.
  Widget _checklistItemContent({
    required BuildContext context,
    required ChecklistItem item,
    required Color? textPrimary,
    required Color primary,
    required Color? textSecondary,
    VoidCallback? onToggle,
    bool isSubLevel = false,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding:
            EdgeInsets.symmetric(vertical: isSubLevel ? 3 : 5, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Checkbox(
                value: item.isChecked,
                activeColor: primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: onToggle != null ? (_) => onToggle() : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: item.isChecked
                      ? textPrimary?.withValues(alpha: 0.4)
                      : textPrimary,
                  fontSize: isSubLevel ? 13 : 14,
                  fontWeight: FontWeight.w400,
                  decoration:
                      item.isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: textPrimary?.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (item.isChecked) ...[
              Icon(Icons.check_circle_rounded,
                  size: 15, color: primary.withValues(alpha: 0.55)),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }

  /// Sub-task tree node.  Shows a header row plus, if the sub-task has
  /// checklist items or nested sub-tasks, renders them below with their
  /// own tree connectors.
  Widget _treeSubTaskRow({
    required BuildContext context,
    required TaskModel task,
    required SubTask st,
    required WidgetRef ref,
    required bool isLast,
    required Color? textPrimary,
    required Color? textSecondary,
    required Color primary,
    required Color lineColor,
  }) {
    final hasChildren = st.checklist.isNotEmpty || st.subTasks.isNotEmpty;
    final isCompleted = st.status == TaskStatus.completed;
    final canComplete = st.canBeCompleted;

    void toggle() {
      final newStatus = isCompleted ? TaskStatus.todo : TaskStatus.completed;
      _updateSubTaskStatus(context, task, st.id, newStatus, ref);
    }

    return _treeItemRow(
      isLast: isLast,
      lineColor: lineColor,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sub-task header ─────────────────────────────────────
            InkWell(
              onTap: canComplete ? toggle : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: Checkbox(
                          value: isCompleted,
                          activeColor: primary,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(hasChildren ? 13 : 6)),
                          onChanged: canComplete ? (_) => toggle() : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sub-task info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "SUB-TASK" chip label
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SUB-TASK',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: primary.withValues(alpha: 0.8),
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Title
                          Text(
                            st.title,
                            style: TextStyle(
                              color: isCompleted
                                  ? textPrimary?.withValues(alpha: 0.45)
                                  : textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor:
                                  textPrimary?.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Metadata badges
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (st.dueDateEnabled && st.dueDate != null)
                                _enhancedBadge(
                                  context,
                                  Icons.calendar_today_rounded,
                                  '${st.dueDateLabel}${st.dueTime != null ? ' ${st.dueTimeLabel}' : ''}',
                                  primary,
                                  compact: true,
                                ),
                              _enhancedBadge(
                                context,
                                Icons.flag_rounded,
                                st.priorityLabel,
                                _priorityColor(st.priority),
                                compact: true,
                              ),
                              _enhancedBadge(
                                context,
                                Icons.folder_rounded,
                                st.categoryLabel,
                                textSecondary,
                                compact: true,
                              ),
                              if (st.totalChecklistItems > 0)
                                _enhancedBadge(
                                  context,
                                  Icons.checklist_rounded,
                                  '${st.completedChecklistItems}/${st.totalChecklistItems}',
                                  textSecondary,
                                  compact: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Children tree ─────────────────────────────────────
            if (hasChildren)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: _buildSubTaskChildrenTree(
                  context: context,
                  task: task,
                  st: st,
                  ref: ref,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primary: primary,
                  lineColor: lineColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Recursively renders checklist items and nested sub-tasks of [st]
  /// with their own tree-line connectors.
  Widget _buildSubTaskChildrenTree({
    required BuildContext context,
    required TaskModel task,
    required SubTask st,
    required WidgetRef ref,
    required Color? textPrimary,
    required Color? textSecondary,
    required Color primary,
    required Color lineColor,
  }) {
    final totalChildren = st.checklist.length + st.subTasks.length;
    var childIdx = 0;
    final widgets = <Widget>[];

    for (final c in st.checklist) {
      childIdx++;
      final isLast = childIdx == totalChildren;
      widgets.add(
        _treeItemRow(
          isLast: isLast,
          lineColor: lineColor,
          child: _checklistItemContent(
            context: context,
            item: c,
            textPrimary: textPrimary,
            primary: primary,
            textSecondary: textSecondary,
            isSubLevel: true,
            onToggle: () =>
                _updateSubTaskChecklist(context, task, st.id, c.id, ref),
          ),
        ),
      );
    }

    for (final nst in st.subTasks) {
      childIdx++;
      final isLast = childIdx == totalChildren;
      widgets.add(
        _treeSubTaskRow(
          context: context,
          task: task,
          st: nst,
          ref: ref,
          isLast: isLast,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          primary: primary,
          lineColor: lineColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _enhancedBadge(
    BuildContext context,
    IconData icon,
    String? label,
    Color? color, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color?.withAlpha(30),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(
          color: color?.withAlpha(80) ?? Colors.grey.withAlpha(80),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 11, color: color),
          if (label != null) ...[
            SizedBox(width: compact ? 3 : 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Auto-complete helper ────────────────────────────────────────────────
  void _handleChecklistUpdate(
      BuildContext context, TaskModel updated, WidgetRef ref) {
    ref.read(taskListProvider.notifier).updateTask(updated);
    if (updated.autoCompleteOnChecklist &&
        updated.totalChecklistItems > 0 &&
        updated.completedChecklistItems == updated.totalChecklistItems &&
        updated.status != TaskStatus.completed) {
      ref.read(taskListProvider.notifier).markComplete(updated.id);
      AppToast.show(
        context,
        'Semua checklist selesai! Task otomatis Completed.',
        type: ToastType.success,
      );
    }
  }

  // ── Helper untuk update subtask status (recursive) ─────────────────────────
  void _updateSubTaskStatus(BuildContext context, TaskModel task,
      String subTaskId, TaskStatus newStatus, WidgetRef ref) {
    final updated = task.copyWith(
      subTasks: _updateSubTaskStatusInList(task.subTasks, subTaskId, newStatus),
    );
    _handleChecklistUpdate(context, updated, ref);
  }

  List<SubTask> _updateSubTaskStatusInList(
      List<SubTask> subTasks, String subTaskId, TaskStatus newStatus) {
    return subTasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(status: newStatus);
      } else if (st.subTasks.isNotEmpty) {
        // Recursively update nested subtasks
        return st.copyWith(
          subTasks:
              _updateSubTaskStatusInList(st.subTasks, subTaskId, newStatus),
        );
      }
      return st;
    }).toList();
  }

  // ── Helper untuk update subtask checklist (recursive) ──────────────────────
  void _updateSubTaskChecklist(BuildContext context, TaskModel task,
      String subTaskId, String checklistId, WidgetRef ref) {
    final updated = task.copyWith(
      subTasks:
          _updateSubTaskChecklistInList(task.subTasks, subTaskId, checklistId),
    );
    _handleChecklistUpdate(context, updated, ref);
  }

  List<SubTask> _updateSubTaskChecklistInList(
      List<SubTask> subTasks, String subTaskId, String checklistId) {
    return subTasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(
          checklist: st.checklist
              .map((item) => item.id == checklistId
                  ? item.copyWith(isChecked: !item.isChecked)
                  : item)
              .toList(),
        );
      } else if (st.subTasks.isNotEmpty) {
        // Recursively update nested subtasks
        return st.copyWith(
          subTasks: _updateSubTaskChecklistInList(
              st.subTasks, subTaskId, checklistId),
        );
      }
      return st;
    }).toList();
  }

  // ── Helper methods ──────────────────────────────────────────────────────────

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

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return priorityLow;
      case TaskPriority.medium:
        return priorityMedium;
      case TaskPriority.high:
        return priorityHigh;
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
