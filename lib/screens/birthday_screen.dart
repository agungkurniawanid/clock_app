import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/birthday_model.dart';
import '../utils/dialog_utils.dart';

class BirthdayScreen extends ConsumerWidget {
  const BirthdayScreen({super.key});

  static const Color _birthdayColor = Color(0xFFFF6B9D);

  static const List<String> _monthNames = [
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthdays = ref.watch(birthdayListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎂', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Birthdays'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBirthdaySheet(context),
        backgroundColor: _birthdayColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: birthdays.isEmpty
          ? _buildEmptyState(context)
          : _buildList(context, ref, birthdays),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _birthdayColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎂', style: TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No birthdays yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your birthdays,\nfamily, or friends',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _showBirthdaySheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Birthday'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _birthdayColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<BirthdayEntry> birthdays) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: birthdays.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final entry = birthdays[i];
        return _BirthdayCard(
          entry: entry,
          monthNames: _monthNames,
          onEdit: () => _showBirthdaySheet(context, entry: entry),
          onDelete: () => _confirmDelete(context, ref, entry),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, BirthdayEntry entry) {
    showScaleDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Birthday'),
        content: Text('Delete birthday for "${entry.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(birthdayListProvider.notifier).deleteEntry(entry.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBirthdaySheet(BuildContext context, {BirthdayEntry? entry}) {
    showScaleBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BirthdayFormSheet(existing: entry),
    );
  }
}

// ── Birthday entry card ───────────────────────────────────────────────────────

class _BirthdayCard extends StatelessWidget {
  final BirthdayEntry entry;
  final List<String> monthNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BirthdayCard({
    required this.entry,
    required this.monthNames,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const birthdayColor = Color(0xFFFF6B9D);
    final nextDate = _nextOccurrence(entry.month, entry.day, DateTime.now());
    final now = DateTime.now();
    final diff =
        DateUtils.dateOnly(nextDate).difference(DateUtils.dateOnly(now)).inDays;
    final String countdown;
    if (diff == 0) {
      countdown = 'Today! 🎉';
    } else if (diff == 1) {
      countdown = 'Tomorrow';
    } else {
      countdown = '$diff days left';
    }
    final isToday = diff == 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? entry.color.withValues(alpha: 0.6)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: entry.color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: entry.color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: const Center(
            child: Text('🎂', style: TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(
          entry.name,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              '${entry.day} ${monthNames[entry.month - 1]} · ${entry.typeLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: entry.color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isToday
                    ? birthdayColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                countdown,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isToday
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded,
                  size: 18, color: Color(0xFFE53E3E)),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _nextOccurrence(int month, int day, DateTime from) {
    final thisYear = DateTime(from.year, month, day);
    if (!thisYear.isBefore(DateUtils.dateOnly(from))) return thisYear;
    final dayInMonth = DateTime(from.year + 1, month + 1, 0).day;
    return DateTime(from.year + 1, month, day.clamp(1, dayInMonth));
  }
}

// ── Birthday add/edit form ────────────────────────────────────────────────────

class _BirthdayFormSheet extends ConsumerStatefulWidget {
  final BirthdayEntry? existing;
  const _BirthdayFormSheet({this.existing});

  @override
  ConsumerState<_BirthdayFormSheet> createState() => _BirthdayFormSheetState();
}

class _BirthdayFormSheetState extends ConsumerState<_BirthdayFormSheet> {
  final _nameController = TextEditingController();
  int _month = DateTime.now().month;
  int _day = DateTime.now().day;
  BirthdayType _type = BirthdayType.self;
  Color _color = BirthdayEntry.paletteColors[0];

  static const List<String> _monthNames = [
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

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _month = widget.existing!.month;
      _day = widget.existing!.day;
      _type = widget.existing!.type;
      _color = widget.existing!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(2000, _month + 1, 0).day;

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    final id =
        widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final entry = BirthdayEntry(
      id: id,
      name: _nameController.text.trim(),
      month: _month,
      day: _day.clamp(1, _daysInMonth),
      type: _type,
      color: _color,
    );
    if (widget.existing == null) {
      ref.read(birthdayListProvider.notifier).addEntry(entry);
    } else {
      ref.read(birthdayListProvider.notifier).updateEntry(entry);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const birthdayColor = Color(0xFFFF6B9D);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 28 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                widget.existing == null ? 'Add Birthday' : 'Edit Birthday',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'E.g.: Alex, Mom, etc.',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Date row: Month + Day
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Month',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _month,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: List.generate(12, (i) {
                        return DropdownMenuItem(
                            value: i + 1, child: Text(_monthNames[i]));
                      }),
                      onChanged: (v) => setState(() {
                        _month = v!;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _day.clamp(1, _daysInMonth),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: List.generate(_daysInMonth, (i) {
                        return DropdownMenuItem(
                            value: i + 1, child: Text('${i + 1}'));
                      }),
                      onChanged: (v) => setState(() => _day = v!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type chips
          Text('Type',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: BirthdayType.values.map((t) {
              final active = _type == t;
              final label = t == BirthdayType.self
                  ? '😊 Me'
                  : t == BirthdayType.friend
                      ? '👫 Friend'
                      : '👨‍👩‍👧 Family';
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? birthdayColor
                        : birthdayColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : birthdayColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('Color',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: BirthdayEntry.paletteColors.map((c) {
              final isSelected = _color.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _color = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 32 : 28,
                  height: isSelected ? 32 : 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: c.withValues(alpha: 0.5), blurRadius: 6)
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _nameController.text.trim().isEmpty ? null : _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(widget.existing == null ? 'Save' : 'Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: birthdayColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
