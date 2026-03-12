import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note_model.dart';

class AddNoteItemScreen extends StatefulWidget {
  final bool isFolder;
  final String? defaultParentId;
  final NoteFolder? editFolder;
  final NoteFile? editFile;

  const AddNoteItemScreen({
    super.key,
    required this.isFolder,
    this.defaultParentId,
    this.editFolder,
    this.editFile,
  });

  @override
  State<AddNoteItemScreen> createState() => _AddNoteItemScreenState();
}

class _AddNoteItemScreenState extends State<AddNoteItemScreen> {
  late final TextEditingController _titleCtrl;
  late Color _selectedColor;
  late bool _reminderEnabled;
  late NoteReminderType _reminderType;
  late bool _reminderRepeat;
  // intervalDays
  late int _intervalDays;
  // dayOfMonth
  late int _dayOfMonth;
  // oneTime
  DateTime? _specificDate;

  static const _folderColors = [
    Color(0xFF7B6EF6), // purple
    Color(0xFF4A90E2), // blue
    Color(0xFF43D8A5), // teal
    Color(0xFFFF6B9D), // pink
    Color(0xFFFFA048), // orange
    Color(0xFF5C6BC0), // indigo
  ];

  static const _fileColors = [
    Color(0xFF43D8A5), // teal
    Color(0xFF7B6EF6), // purple
    Color(0xFF4A90E2), // blue
    Color(0xFFFF6B9D), // pink
    Color(0xFFFFA048), // orange
    Color(0xFF26C6DA), // cyan
  ];

  List<Color> get _colorPalette =>
      widget.isFolder ? _folderColors : _fileColors;

  @override
  void initState() {
    super.initState();
    if (widget.isFolder && widget.editFolder != null) {
      final f = widget.editFolder!;
      _titleCtrl = TextEditingController(text: f.title);
      _selectedColor = f.color;
      final r = f.reminder;
      _reminderEnabled = r?.isEnabled ?? false;
      _reminderType = r?.type ?? NoteReminderType.intervalDays;
      _reminderRepeat = r?.repeat ?? true;
      _intervalDays = r?.intervalDays ?? 7;
      _dayOfMonth = r?.dayOfMonth ?? 1;
      _specificDate = r?.specificDate;
    } else if (!widget.isFolder && widget.editFile != null) {
      final f = widget.editFile!;
      _titleCtrl = TextEditingController(text: f.title);
      _selectedColor = f.color;
      final r = f.reminder;
      _reminderEnabled = r?.isEnabled ?? false;
      _reminderType = r?.type ?? NoteReminderType.intervalDays;
      _reminderRepeat = r?.repeat ?? true;
      _intervalDays = r?.intervalDays ?? 7;
      _dayOfMonth = r?.dayOfMonth ?? 1;
      _specificDate = r?.specificDate;
    } else {
      _titleCtrl = TextEditingController();
      _selectedColor = _colorPalette.first;
      _reminderEnabled = false;
      _reminderType = NoteReminderType.intervalDays;
      _reminderRepeat = true;
      _intervalDays = 7;
      _dayOfMonth = 1;
      _specificDate = null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  NoteReminder? _buildReminder() {
    if (!_reminderEnabled) return null;
    return NoteReminder(
      type: _reminderType,
      intervalDays: _intervalDays,
      dayOfMonth: _dayOfMonth,
      specificDate: _specificDate,
      repeat: _reminderRepeat,
      isEnabled: true,
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }
    final reminder = _buildReminder();

    if (widget.isFolder) {
      late NoteFolder result;
      if (widget.editFolder != null) {
        result = widget.editFolder!.copyWith(
          title: title,
          colorValue: _selectedColor.toARGB32(),
          reminder: reminder,
          clearReminder: reminder == null,
        );
      } else {
        result = NoteFolder(
          id: _generateId(),
          title: title,
          colorValue: _selectedColor.toARGB32(),
          parentFolderId: widget.defaultParentId,
          reminder: reminder,
          createdAt: DateTime.now(),
        );
      }
      Navigator.pop(context, result);
    } else {
      late NoteFile result;
      if (widget.editFile != null) {
        result = widget.editFile!.copyWith(
          title: title,
          colorValue: _selectedColor.toARGB32(),
          reminder: reminder,
          clearReminder: reminder == null,
        );
      } else {
        final now = DateTime.now();
        result = NoteFile(
          id: _generateId(),
          title: title,
          content: '',
          folderId: widget.defaultParentId,
          colorValue: _selectedColor.toARGB32(),
          reminder: reminder,
          createdAt: now,
          updatedAt: now,
        );
      }
      Navigator.pop(context, result);
    }
  }

  String _generateId() => 'note_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final isEditing = (widget.isFolder && widget.editFolder != null) ||
        (!widget.isFolder && widget.editFile != null);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: Text(
          isEditing
              ? (widget.isFolder ? 'Edit Folder' : 'Edit Note')
              : (widget.isFolder ? 'New Folder' : 'New Note'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _submit,
            child: Text(
              isEditing ? 'Save' : 'Create',
              style: TextStyle(fontWeight: FontWeight.w700, color: primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title
          _sectionLabel('Title'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.isFolder ? 'Folder name' : 'Note title',
              filled: true,
              fillColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Color picker
          _sectionLabel('Color'),
          const SizedBox(height: 10),
          Row(
            children: _colorPalette.map((color) {
              final selected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  width: selected ? 36 : 30,
                  height: selected ? 36 : 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Reminder
          _sectionLabel('Reminder'),
          const SizedBox(height: 10),
          _ReminderSection(
            isDark: isDark,
            primary: primary,
            enabled: _reminderEnabled,
            type: _reminderType,
            repeat: _reminderRepeat,
            intervalDays: _intervalDays,
            dayOfMonth: _dayOfMonth,
            specificDate: _specificDate,
            onEnabledChanged: (v) => setState(() => _reminderEnabled = v),
            onTypeChanged: (v) => setState(() => _reminderType = v),
            onRepeatChanged: (v) => setState(() => _reminderRepeat = v),
            onIntervalDaysChanged: (v) => setState(() => _intervalDays = v),
            onDayOfMonthChanged: (v) => setState(() => _dayOfMonth = v),
            onSpecificDateChanged: (v) => setState(() => _specificDate = v),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reminder Section widget
// ─────────────────────────────────────────────────────────────────────────────
class _ReminderSection extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final bool enabled;
  final NoteReminderType type;
  final bool repeat;
  final int intervalDays;
  final int dayOfMonth;
  final DateTime? specificDate;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<NoteReminderType> onTypeChanged;
  final ValueChanged<bool> onRepeatChanged;
  final ValueChanged<int> onIntervalDaysChanged;
  final ValueChanged<int> onDayOfMonthChanged;
  final ValueChanged<DateTime?> onSpecificDateChanged;

  const _ReminderSection({
    required this.isDark,
    required this.primary,
    required this.enabled,
    required this.type,
    required this.repeat,
    required this.intervalDays,
    required this.dayOfMonth,
    required this.specificDate,
    required this.onEnabledChanged,
    required this.onTypeChanged,
    required this.onRepeatChanged,
    required this.onIntervalDaysChanged,
    required this.onDayOfMonthChanged,
    required this.onSpecificDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Enable toggle
          SwitchListTile(
            title: const Text('Enable reminder',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Get notified to revisit this item'),
            value: enabled,
            onChanged: onEnabledChanged,
            activeColor: primary,
          ),
          if (enabled) ...[
            const Divider(height: 1),
            // Type selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Type chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TypeChip(
                        label: 'Every N days',
                        icon: Icons.repeat_rounded,
                        selected: type == NoteReminderType.intervalDays,
                        primary: primary,
                        onTap: () =>
                            onTypeChanged(NoteReminderType.intervalDays),
                      ),
                      _TypeChip(
                        label: 'Day of month',
                        icon: Icons.calendar_today_rounded,
                        selected: type == NoteReminderType.dayOfMonth,
                        primary: primary,
                        onTap: () => onTypeChanged(NoteReminderType.dayOfMonth),
                      ),
                      _TypeChip(
                        label: 'Specific date',
                        icon: Icons.event_rounded,
                        selected: type == NoteReminderType.oneTime,
                        primary: primary,
                        onTap: () => onTypeChanged(NoteReminderType.oneTime),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Type-specific config
                  if (type == NoteReminderType.intervalDays)
                    _IntervalDaysConfig(
                      days: intervalDays,
                      onChanged: onIntervalDaysChanged,
                      isDark: isDark,
                    )
                  else if (type == NoteReminderType.dayOfMonth)
                    _DayOfMonthConfig(
                      day: dayOfMonth,
                      onChanged: onDayOfMonthChanged,
                      isDark: isDark,
                    )
                  else
                    _SpecificDateConfig(
                      date: specificDate,
                      onChanged: onSpecificDateChanged,
                      primary: primary,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Repeat toggle (hidden for one-time)
            if (type != NoteReminderType.oneTime)
              SwitchListTile(
                title: const Text('Repeat',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  repeat
                      ? 'Reminder repeats each cycle'
                      : 'Reminder fires once then stops',
                ),
                value: repeat,
                onChanged: onRepeatChanged,
                activeColor: primary,
              ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: primary, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalDaysConfig extends StatefulWidget {
  final int days;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const _IntervalDaysConfig(
      {required this.days, required this.onChanged, required this.isDark});

  @override
  State<_IntervalDaysConfig> createState() => _IntervalDaysConfigState();
}

class _IntervalDaysConfigState extends State<_IntervalDaysConfig> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.days.toString());
  }

  @override
  void didUpdateWidget(_IntervalDaysConfig old) {
    super.didUpdateWidget(old);
    if (old.days != widget.days && _ctrl.text != widget.days.toString()) {
      _ctrl.text = widget.days.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Every',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            controller: _ctrl,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 1) widget.onChanged(n);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.isDark
                  ? const Color(0xFF2A2A3A)
                  : const Color(0xFFF0F0FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'days',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _DayOfMonthConfig extends StatelessWidget {
  final int day;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const _DayOfMonthConfig(
      {required this.day, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day of month (1–28)',
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(28, (i) {
            final d = i + 1;
            final selected = d == day;
            return GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : isDark
                          ? const Color(0xFF2A2A3A)
                          : const Color(0xFFF0F0FA),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : null,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SpecificDateConfig extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  final Color primary;

  const _SpecificDateConfig(
      {required this.date, required this.onChanged, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder date (one-time)',
          style: TextStyle(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Text(
            date != null ? _formatDate(date!) : 'Pick a date',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';
}
