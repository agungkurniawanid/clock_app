import 'package:flutter/material.dart';
import '../models/task_model.dart';

class AlarmModeIcon extends StatelessWidget {
  final AlarmMode mode;
  final double size;

  const AlarmModeIcon({super.key, required this.mode, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final icon = mode == AlarmMode.alarmMusic
        ? Icons.music_note_rounded
        : Icons.notifications_rounded;
    final color = mode == AlarmMode.alarmMusic
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.primary;

    return Tooltip(
      message:
          mode == AlarmMode.alarmMusic ? 'Music Alarm' : 'Notification Alarm',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}
