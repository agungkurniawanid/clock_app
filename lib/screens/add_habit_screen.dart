import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../providers/app_providers.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  final HabitModel? editHabit;

  const AddHabitScreen({super.key, this.editHabit});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  HabitCategory _category = HabitCategory.health;
  HabitFrequency _frequency = HabitFrequency.daily;
  List<bool> _weekDays = List.filled(7, false);
  int _targetCount = 1;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime? _endDate;
  Color _colorTag = const Color(0xFF7B6EF6);

  static const _colorOptions = [
    Color(0xFF7B6EF6),
    Color(0xFF4ECDC4),
    Color(0xFFFF6B9D),
    Color(0xFF4A90E2),
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ];

  bool get _isEdit => widget.editHabit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.editHabit;
    if (h != null) {
      _titleController.text = h.title;
      _descController.text = h.description;
      _category = h.category;
      _frequency = h.frequency;
      _weekDays = List.from(h.weekDays);
      _targetCount = h.targetCount;
      _reminderEnabled = h.reminderEnabled;
      _reminderTime = h.reminderTime;
      _startDate = h.startDate;
      _endDate = h.endDate;
      _colorTag = h.colorTag;
    } else {
      // Default: Mon–Fri selected for weekly
      _weekDays = [false, true, true, true, true, true, false];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = DateUtils.dateOnly(picked));
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == HabitFrequency.weekly && !_weekDays.any((d) => d)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one day for weekly habit.')),
      );
      return;
    }

    final notifier = ref.read(habitListProvider.notifier);

    if (_isEdit) {
      final updated = widget.editHabit!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        frequency: _frequency,
        weekDays: _weekDays,
        targetCount: _targetCount,
        reminderEnabled: _reminderEnabled,
        reminderTime: _reminderEnabled ? _reminderTime : null,
        clearReminderTime: !_reminderEnabled,
        startDate: _startDate,
        endDate: _endDate,
        clearEndDate: _endDate == null,
        colorTag: _colorTag,
        history: [
          ...widget.editHabit!.history,
          'Updated on ${_todayLabel()}',
        ],
      );
      notifier.updateHabit(updated);
    } else {
      final id = 'habit_${DateTime.now().millisecondsSinceEpoch}';
      final habit = HabitModel(
        id: id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        frequency: _frequency,
        weekDays: _weekDays,
        targetCount: _targetCount,
        reminderEnabled: _reminderEnabled,
        reminderTime: _reminderEnabled ? _reminderTime : null,
        startDate: _startDate,
        endDate: _endDate,
        colorTag: _colorTag,
        completionLog: const {},
        isArchived: false,
        history: ['Created on ${_todayLabel()}'],
      );
      notifier.addHabit(habit);
    }
    Navigator.pop(context);
  }

  String _todayLabel() {
    final now = DateTime.now();
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
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Habit' : 'New Habit',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Habit'),
                    content: Text(
                        'Delete "${widget.editHabit!.title}"? This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref
                      .read(habitListProvider.notifier)
                      .deleteHabit(widget.editHabit!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              _isEdit ? 'Update' : 'Save',
              style: TextStyle(fontWeight: FontWeight.w700, color: primary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ──────────────────────────────────────────────────────
            _SectionLabel(label: 'Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('e.g. Morning Exercise'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────────
            _SectionLabel(label: 'Description (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: _inputDecoration('Add a note…'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ── Category ───────────────────────────────────────────────────
            _SectionLabel(label: 'Category'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitCategory.values.map((c) {
                final selected = _category == c;
                return ChoiceChip(
                  label: Text(_categoryLabel(c)),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Color ───────────────────────────────────────────────────────
            _SectionLabel(label: 'Color'),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colorOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final color = _colorOptions[i];
                  final selected = _colorTag.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _colorTag = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: selected
                            ? Border.all(
                                color: onSurface.withValues(alpha: 0.7),
                                width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Frequency ──────────────────────────────────────────────────
            _SectionLabel(label: 'Frequency'),
            const SizedBox(height: 10),
            Row(
              children: HabitFrequency.values.map((f) {
                final selected = _frequency == f;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Center(child: Text(_frequencyLabel(f))),
                      selected: selected,
                      onSelected: (_) => setState(() => _frequency = f),
                      selectedColor: primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Weekday selector (only for weekly) ─────────────────────────
            if (_frequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 16),
              _SectionLabel(label: 'Days of Week'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                  final active = _weekDays[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _weekDays[i] = !_weekDays[i]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            active ? primary : primary.withValues(alpha: 0.1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: active ? Colors.white : primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 20),

            // ── Target count ───────────────────────────────────────────────
            _SectionLabel(label: 'Daily target (times per day)'),
            const SizedBox(height: 10),
            Row(
              children: [
                _CounterButton(
                  icon: Icons.remove,
                  onTap: _targetCount > 1
                      ? () => setState(() => _targetCount--)
                      : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '$_targetCount',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 16),
                _CounterButton(
                  icon: Icons.add,
                  onTap: _targetCount < 10
                      ? () => setState(() => _targetCount++)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  _targetCount == 1 ? 'time' : 'times',
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.6), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Dates ──────────────────────────────────────────────────────
            _SectionLabel(label: 'Dates'),
            const SizedBox(height: 10),
            _DateRow(
              label: 'Start Date',
              value: _formatDate(_startDate),
              onTap: _pickStartDate,
              surface: surface,
              onSurface: onSurface,
            ),
            const SizedBox(height: 10),
            _DateRow(
              label: 'End Date (optional)',
              value: _endDate != null ? _formatDate(_endDate!) : 'No end date',
              onTap: _pickEndDate,
              trailing: _endDate != null
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 18, color: onSurface.withValues(alpha: 0.5)),
                      onPressed: () => setState(() => _endDate = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              surface: surface,
              onSurface: onSurface,
            ),
            const SizedBox(height: 20),

            // ── Reminder ───────────────────────────────────────────────────
            _SectionLabel(label: 'Reminder'),
            const SizedBox(height: 10),
            Material(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.06),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Reminder',
                          style: TextStyle(fontSize: 14)),
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (_reminderEnabled)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Reminder Time',
                            style: TextStyle(fontSize: 14)),
                        trailing: Text(
                          _reminderTime != null
                              ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                              : 'Tap to set',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: _pickReminderTime,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isEdit ? 'Update Habit' : 'Save Habit',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String _categoryLabel(HabitCategory c) {
    switch (c) {
      case HabitCategory.health:
        return 'Health';
      case HabitCategory.fitness:
        return 'Fitness';
      case HabitCategory.learning:
        return 'Learning';
      case HabitCategory.mindfulness:
        return 'Mindfulness';
      case HabitCategory.productivity:
        return 'Productivity';
      case HabitCategory.social:
        return 'Social';
      case HabitCategory.other:
        return 'Other';
    }
  }

  String _frequencyLabel(HabitFrequency f) {
    switch (f) {
      case HabitFrequency.daily:
        return 'Daily';
      case HabitFrequency.weekly:
        return 'Weekly';
      case HabitFrequency.monthly:
        return 'Monthly';
    }
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color surface;
  final Color onSurface;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.surface,
    required this.onSurface,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? primary.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? primary : Colors.grey,
        ),
      ),
    );
  }
}
