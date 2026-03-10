import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Quick actions menu shown on long-press of subtasks/checklist items
class QuickActionsMenu {
  static Future<String?> show(
    BuildContext context, {
    required Offset tapPosition,
    bool isSubTask = false,
    bool hasReminder = false,
    bool hasDueDate = false,
    bool hasPriority = false,
    bool hasNotes = false,
  }) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? darkCard : lightCard;

    return await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        // Add/Remove reminder
        PopupMenuItem<String>(
          value: 'toggle_reminder',
          child: _menuItem(
            context,
            hasReminder
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_rounded,
            hasReminder ? 'Remove Reminder' : 'Add Reminder',
            hasReminder ? statusRisk : null,
          ),
        ),

        // Set due date
        PopupMenuItem<String>(
          value: 'set_due_date',
          child: _menuItem(
            context,
            hasDueDate ? Icons.event_rounded : Icons.calendar_today_rounded,
            hasDueDate ? 'Edit Due Date' : 'Set Due Date',
          ),
        ),

        // Set priority
        PopupMenuItem<String>(
          value: 'set_priority',
          child: _menuItem(
            context,
            hasPriority ? Icons.flag_rounded : Icons.outlined_flag_rounded,
            hasPriority ? 'Edit Priority' : 'Set Priority',
          ),
        ),

        // Add/Edit notes
        if (isSubTask)
          PopupMenuItem<String>(
            value: 'add_notes',
            child: _menuItem(
              context,
              hasNotes ? Icons.notes_rounded : Icons.note_add_rounded,
              hasNotes ? 'Edit Notes' : 'Add Notes',
            ),
          ),

        const PopupMenuDivider(),

        // Convert to full task (only for subtasks)
        if (isSubTask)
          PopupMenuItem<String>(
            value: 'convert_to_task',
            child: _menuItem(
              context,
              Icons.move_up_rounded,
              'Convert to Full Task',
              Theme.of(context).colorScheme.primary,
            ),
          ),

        // Delete
        PopupMenuItem<String>(
          value: 'delete',
          child: _menuItem(
            context,
            Icons.delete_rounded,
            'Delete',
            statusOverdue,
          ),
        ),
      ],
    );
  }

  static Widget _menuItem(
    BuildContext context,
    IconData icon,
    String label, [
    Color? color,
  ]) {
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final effectiveColor = color ?? textPrimary;

    return Row(
      children: [
        Icon(icon, size: 18, color: effectiveColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
