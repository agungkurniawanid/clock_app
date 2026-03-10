import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import 'status_badge.dart';
import 'alarm_mode_icon.dart';
import '../theme/app_colors.dart';

class SwipeableCard extends StatefulWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const SwipeableCard({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> {
  static final _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  String _shortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
      return host.isEmpty ? 'link' : host;
    } catch (_) {
      return 'link';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.task.id),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          widget.onComplete?.call();
          return false;
        } else {
          widget.onDelete?.call();
          return false;
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: statusCompleted.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: statusCompleted, size: 26),
            SizedBox(width: 8),
            Text(
              'Complete',
              style: TextStyle(
                color: statusCompleted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: statusOverdue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: statusOverdue,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: statusOverdue, size: 26),
          ],
        ),
      ),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? darkCard : lightCard;
    final textPrimary =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final task = widget.task;
    final priorityColor = _priorityColor(task.priority);
    final hasProgress = task.totalChecklistItems > 0;
    final progressValue = hasProgress
        ? task.completedChecklistItems / task.totalChecklistItems
        : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Color tag left border ───────────────────────────────
                Container(width: 4, color: task.colorTag),

                // ── Main content ────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Row 1: Title + Status badge ────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _buildTextWithUrls(
                                      context,
                                      task.title,
                                      textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  StatusBadge(status: task.status),
                                ],
                              ),

                              const SizedBox(height: 5),

                              // ── Row 2: Priority + Category badges ──────
                              Row(
                                children: [
                                  _priorityBadge(priorityColor, task.priority),
                                  const SizedBox(width: 6),
                                  _categoryBadge(task.category),
                                ],
                              ),

                              // ── Row 3: Description ─────────────────────
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                _buildTextWithUrls(
                                  context,
                                  task.description,
                                  textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  maxLines: 2,
                                ),
                              ],

                              const SizedBox(height: 8),
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                color: textSecondary.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 7),

                              // ── Row 4: Start date & time ───────────────
                              _dateTimeRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Start',
                                dateStr: _formatDate(task.date),
                                timeStr: task.timeLabel,
                                color: textSecondary,
                              ),

                              // ── Row 5: Due date (only if enabled) ──────
                              if (task.dueDateEnabled &&
                                  task.dueDate != null) ...[
                                const SizedBox(height: 4),
                                _dateTimeRow(
                                  icon: Icons.flag_rounded,
                                  label: 'Due',
                                  dateStr: task.dueDateLabel ?? '',
                                  timeStr: task.dueTimeLabel,
                                  color: _dueColor(task),
                                  isDue: true,
                                ),
                              ],

                              const SizedBox(height: 6),

                              // ── Row 6: Repeat / Alarm / Music chips ────
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (task.repeat != RepeatType.none)
                                    _infoChip(
                                      context,
                                      Icons.repeat_rounded,
                                      task.repeatLabel,
                                    ),
                                  AlarmModeIcon(mode: task.alarmMode, size: 12),
                                  if (task.musicFile != null)
                                    _infoChip(
                                      context,
                                      Icons.music_note_rounded,
                                      task.musicFile!
                                          .split(RegExp(r'[/\\]'))
                                          .last,
                                    ),
                                ],
                              ),

                              // ── Row 7: Checklist / subtask progress ────
                              if (hasProgress) ...[
                                const SizedBox(height: 8),
                                _progressRow(
                                  context,
                                  task,
                                  progressValue,
                                  textSecondary,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── 3-dot menu ──────────────────────────────────
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              color: textSecondary, size: 20),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'complete',
                                child: Text('Mark Complete')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') widget.onEdit?.call();
                            if (v == 'complete') widget.onComplete?.call();
                            if (v == 'delete') widget.onDelete?.call();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Text builder with clickable URL detection ───────────────────────────────
  Widget _buildTextWithUrls(
    BuildContext context,
    String text,
    Color baseColor, {
    required double fontSize,
    required FontWeight fontWeight,
    required int maxLines,
  }) {
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
            color: baseColor, fontSize: fontSize, fontWeight: fontWeight),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
              color: baseColor, fontSize: fontSize, fontWeight: fontWeight),
        ));
      }

      final url = match.group(0)!;
      final shortLabel = _shortUrl(url);

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 11, color: primary),
                const SizedBox(width: 2),
                Text(
                  shortLabel,
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
            color: baseColor, fontSize: fontSize, fontWeight: fontWeight),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Priority badge ──────────────────────────────────────────────────────────
  Widget _priorityBadge(Color color, TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            _priorityLabel(priority),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── Category badge ──────────────────────────────────────────────────────────
  Widget _categoryBadge(TaskCategory category) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _categoryLabel(category),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Date + time row ─────────────────────────────────────────────────────────
  Widget _dateTimeRow({
    required IconData icon,
    required String label,
    required String dateStr,
    String? timeStr,
    required Color color,
    bool isDue = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          dateStr,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        if (timeStr != null) ...[
          const SizedBox(width: 5),
          Icon(Icons.access_time_rounded, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            timeStr,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
        if (isDue) ...[
          const SizedBox(width: 4),
          Icon(Icons.notifications_rounded,
              size: 11, color: color.withValues(alpha: 0.7)),
        ],
      ],
    );
  }

  // ── Progress row ────────────────────────────────────────────────────────────
  Widget _progressRow(
    BuildContext context,
    TaskModel task,
    double value,
    Color textSecondary,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final completed = task.completedChecklistItems;
    final total = task.totalChecklistItems;
    final hasSubTasks = task.subTasks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasSubTasks
                  ? Icons.account_tree_rounded
                  : Icons.checklist_rounded,
              size: 11,
              color: textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '$completed / $total ${hasSubTasks ? 'tasks' : 'items'}',
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: value >= 1.0 ? statusCompleted : primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: textSecondary.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 1.0 ? statusCompleted : primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Info chip ───────────────────────────────────────────────────────────────
  Widget _infoChip(BuildContext context, IconData icon, String label) {
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return priorityLow;
      case TaskPriority.medium:
        return priorityMedium;
      case TaskPriority.high:
        return priorityHigh;
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color _categoryColor(TaskCategory category) {
    switch (category) {
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

  String _categoryLabel(TaskCategory category) {
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

  Color _dueColor(TaskModel task) {
    final now = DateTime.now();
    if (task.dueDate != null && task.dueDate!.isBefore(now)) {
      return statusOverdue;
    }
    return statusRisk;
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
      'Dec'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}
