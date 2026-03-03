import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../data/dummy_data.dart';
import '../theme/app_colors.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final TaskModel? editTask;

  const AddTaskScreen({super.key, this.editTask});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editTask != null) {
      final t = widget.editTask!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final n = ref.read(addTaskFormProvider.notifier);
        n.setTitle(t.title);
        n.setDescription(t.description);
        n.setCategory(t.category);
        n.setDate(t.date);
        n.setTime(t.time);
        n.setAlarmMode(t.alarmMode);
        n.setMusicFile(t.musicFile);
        n.setVolume(t.volume.toDouble());
        n.setSnooze(t.snoozeMinutes);
        n.setRepeat(t.repeat);
        n.setPriority(t.priority);
        n.setColorTag(t.colorTag);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addTaskFormProvider.notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(addTaskFormProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.editTask != null ? 'Edit Schedule' : 'Add New Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
              context, '① Basic Info', _buildBasicInfo(context, form, card)),
          const SizedBox(height: 16),
          _section(
              context, '② Date & Time', _buildDateTime(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '③ Reminder Settings',
              _buildReminders(context, form, card)),
          const SizedBox(height: 16),
          _section(
              context, '④ Alarm Mode', _buildAlarmMode(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '⑤ Repeat', _buildRepeat(context, form, card)),
          const SizedBox(height: 16),
          _section(context, '⑥ Priority & Color Tag',
              _buildPriorityColor(context, form, card)),
          const SizedBox(height: 28),
          // Bottom Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Schedule'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _save() {
    final form = ref.read(addTaskFormProvider);
    if (form.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    final newTask = TaskModel(
      id: widget.editTask?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: form.title,
      description: form.description,
      category: form.category,
      status: widget.editTask?.status ?? TaskStatus.todo,
      priority: form.priority,
      date: form.date,
      time: form.time,
      alarmMode: form.alarmMode,
      musicFile: form.musicFile,
      volume: form.volume.round(),
      snoozeMinutes: form.snoozeMinutes,
      repeat: form.repeat,
      weekDays: form.weekDays,
      reminders: form.reminders,
      colorTag: form.colorTag,
      history: widget.editTask?.history ?? [],
    );
    if (widget.editTask != null) {
      ref.read(taskListProvider.notifier).updateTask(newTask);
    } else {
      ref.read(taskListProvider.notifier).addTask(newTask);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(widget.editTask != null
              ? 'Schedule updated!'
              : 'Schedule saved!')),
    );
  }

  Widget _section(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildBasicInfo(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    final categories = TaskCategory.values;

    return Column(
      children: [
        TextField(
          controller: _titleCtrl,
          onChanged: notifier.setTitle,
          decoration: const InputDecoration(hintText: 'Task title *'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descCtrl,
          onChanged: notifier.setDescription,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Description (optional)'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final active = form.category == c;
            return GestureDetector(
              onTap: () => notifier.setCategory(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.name[0].toUpperCase() + c.name.substring(1),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateTime(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
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

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: form.date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) notifier.setDate(picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    '${form.date.day} ${months[form.date.month - 1]} ${form.date.year}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: form.time,
              );
              if (picked != null) notifier.setTime(picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(Icons.access_time_rounded, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    '${form.time.hour.toString().padLeft(2, '0')}:${form.time.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminders(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Enable Reminder',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Switch(
                value: form.reminderEnabled,
                onChanged: notifier.toggleReminder),
          ],
        ),
        if (form.reminderEnabled) ...[
          const SizedBox(height: 12),
          ...form.reminders.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_rounded, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(r,
                            style: Theme.of(context).textTheme.bodyMedium)),
                    GestureDetector(
                      onTap: () => notifier.removeReminder(r),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _showReminderSheet(context, notifier),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Reminder'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ],
    );
  }

  void _showReminderSheet(BuildContext context, AddTaskFormNotifier notifier) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('Add Reminder',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            ...reminderOptions.where((r) => r != 'Custom').map((r) => ListTile(
                  leading: const Icon(Icons.alarm_rounded),
                  title: Text(r),
                  onTap: () {
                    notifier.addReminder(r);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmMode(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _radioTile(context, 'Notification Only', AlarmMode.notificationOnly,
            form.alarmMode, (v) => notifier.setAlarmMode(v!)),
        _radioTile(context, 'Alarm Music Mode', AlarmMode.alarmMusic,
            form.alarmMode, (v) => notifier.setAlarmMode(v!)),
        if (form.alarmMode == AlarmMode.alarmMusic) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        form.musicFile ?? 'No music selected',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Choose →'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Volume'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: form.volume,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${form.volume.round()}%',
                        onChanged: notifier.setVolume,
                      ),
                    ),
                    Text('${form.volume.round()}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                Row(
                  children: [
                    const Text('Snooze'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: form.snoozeMinutes,
                      underline: const SizedBox(),
                      items: [5, 10, 15, 20, 30]
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text('$v min')))
                          .toList(),
                      onChanged: (v) => notifier.setSnooze(v!),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _radioTile<T>(BuildContext context, String label, T value,
      T groupValue, ValueChanged<T?> onChanged) {
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildRepeat(BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    const repeatOptions = RepeatType.values;
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: repeatOptions.map((r) {
            final active = form.repeat == r;
            return GestureDetector(
              onTap: () => notifier.setRepeat(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r.name[0].toUpperCase() + r.name.substring(1),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (form.repeat == RepeatType.weekly) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = form.weekDays[i];
              return GestureDetector(
                onTap: () => notifier.toggleWeekDay(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayLabels[i],
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityColor(
      BuildContext context, AddTaskFormState form, Color card) {
    final notifier = ref.read(addTaskFormProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: TaskPriority.values.map((p) {
            final active = form.priority == p;
            Color pColor;
            switch (p) {
              case TaskPriority.low:
                pColor = priorityLow;
                break;
              case TaskPriority.medium:
                pColor = priorityMedium;
                break;
              case TaskPriority.high:
                pColor = priorityHigh;
                break;
            }
            return GestureDetector(
              onTap: () => notifier.setPriority(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? pColor : pColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: active ? pColor : pColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: active ? Colors.white : pColor,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      p.name[0].toUpperCase() + p.name.substring(1),
                      style: TextStyle(
                        color: active ? Colors.white : pColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Text('Color Tag',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: colorTags.map((c) {
            final active = form.colorTag.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => notifier.setColorTag(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                width: active ? 36 : 30,
                height: active ? 36 : 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border:
                      active ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: c.withValues(alpha: 0.5), blurRadius: 8)
                        ]
                      : null,
                ),
                child: active
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
