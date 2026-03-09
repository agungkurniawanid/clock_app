import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final TaskStatus status;
  final bool large;

  const StatusBadge({super.key, required this.status, this.large = false});

  Color get _color {
    switch (status) {
      case TaskStatus.upcoming:
        return statusUpcoming;
      case TaskStatus.todo:
        return statusTodo;
      case TaskStatus.inProgress:
        return statusInProgress;
      case TaskStatus.risk:
        return statusRisk;
      case TaskStatus.overdue:
        return statusOverdue;
      case TaskStatus.completed:
        return statusCompleted;
    }
  }

  String get _label {
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
        return 'Done';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: large ? 13 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;

  const PriorityBadge({super.key, required this.priority});

  Color get _color {
    switch (priority) {
      case TaskPriority.low:
        return priorityLow;
      case TaskPriority.medium:
        return priorityMedium;
      case TaskPriority.high:
        return priorityHigh;
    }
  }

  String get _label {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
