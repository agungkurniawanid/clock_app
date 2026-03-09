import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/task_model.dart';
import '../theme/app_colors.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _filterType = 0; // 0=Week, 1=Month, 2=Year, 3=Range

  final int _currentYear = DateTime.now().year;
  final int _currentMonth = DateTime.now().month;

  late int _selectedYear;
  late int _selectedMonth;

  DateTime? _startDate;
  DateTime? _endDate;

  static const _monthNames = [
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
    'Dec',
  ];
  static const _filterLabels = ['Week', 'Month', 'Year', 'Range'];
  static const _filterIcons = [
    Icons.view_week_rounded,
    Icons.calendar_month_rounded,
    Icons.calendar_today_rounded,
    Icons.date_range_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = _currentYear;
    _selectedMonth = _currentMonth;
  }

  String get _periodLabel {
    switch (_filterType) {
      case 0:
        return 'This Week';
      case 1:
        return '${_monthNames[_selectedMonth - 1]} $_selectedYear';
      case 2:
        return '$_selectedYear';
      case 3:
        if (_startDate != null && _endDate != null) {
          return '${_fmtDate(_startDate!)} – ${_fmtDate(_endDate!)}';
        }
        return 'Select Range';
      default:
        return '';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  // ── Filter tasks based on current period selection ────────────────────────
  List<TaskModel> _filterTasks(List<TaskModel> all) {
    final now = DateTime.now();
    switch (_filterType) {
      case 0: // This week (Mon–Sun)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = start.add(const Duration(days: 6));
        return all.where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          return !d.isBefore(start) && !d.isAfter(end);
        }).toList();

      case 1: // Month
        return all
            .where((t) =>
                t.date.year == _selectedYear && t.date.month == _selectedMonth)
            .toList();

      case 2: // Year
        return all.where((t) => t.date.year == _selectedYear).toList();

      case 3: // Range
        if (_startDate == null || _endDate == null) return all;
        final s =
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final e =
            DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59);
        return all.where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          return !d.isBefore(s) && !d.isAfter(e);
        }).toList();

      default:
        return all;
    }
  }

  // ── Summary calculations ───────────────────────────────────────────────────
  Map<String, dynamic> _computeSummary(List<TaskModel> tasks) {
    final total = tasks.length;
    final completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final overdue = tasks.where((t) => t.status == TaskStatus.overdue).length;
    final pct = total > 0 ? (completed / total * 100).round() : 0;
    return {'pct': pct, 'done': completed, 'overdue': overdue, 'total': total};
  }

  // ── Weekly bar chart data (Mon–Sun relative to selected period) ────────────
  List<Map<String, dynamic>> _computeWeeklyBars(List<TaskModel> tasks) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    // Always show Mon–Sun of the current week for simplicity
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      final dayTasks = tasks
          .where((t) =>
              t.date.year == day.year &&
              t.date.month == day.month &&
              t.date.day == day.day)
          .toList();
      final total = dayTasks.length;
      final completed =
          dayTasks.where((t) => t.status == TaskStatus.completed).length;
      final pct = total > 0 ? completed / total : 0.0;
      return {
        'day': dayNames[i],
        'percent': pct,
        'done': completed,
        'total': total,
      };
    });
  }

  // ── Category breakdown ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _computeCategories(List<TaskModel> tasks) {
    if (tasks.isEmpty) return [];
    final counts = <TaskCategory, int>{};
    for (final t in tasks) {
      counts[t.category] = (counts[t.category] ?? 0) + 1;
    }
    final total = tasks.length;
    final colors = {
      TaskCategory.work: categoryWork,
      TaskCategory.personal: categoryPersonal,
      TaskCategory.health: categoryHealth,
      TaskCategory.study: categoryStudy,
      TaskCategory.other: categoryOther,
    };
    final labels = {
      TaskCategory.work: 'Work',
      TaskCategory.personal: 'Personal',
      TaskCategory.health: 'Health',
      TaskCategory.study: 'Study',
      TaskCategory.other: 'Other',
    };
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .map((e) => {
              'label': labels[e.key]!,
              'percent': e.value / total,
              'color': colors[e.key]!,
            })
        .toList();
  }

  // ── Streak calculation ─────────────────────────────────────────────────────
  Map<String, int> _computeStreak(List<TaskModel> all) {
    // Current streak: consecutive days up to today where ≥1 task completed
    final completedDates = all
        .where((t) => t.status == TaskStatus.completed)
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int current = 0;
    DateTime check =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final d in completedDates) {
      if (d == check) {
        current++;
        check = check.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }

    // Best streak
    if (completedDates.isEmpty) return {'current': 0, 'best': 0};
    final allDates = completedDates.toSet().toList()..sort();
    int best = 1, streak = 1;
    for (int i = 1; i < allDates.length; i++) {
      if (allDates[i].difference(allDates[i - 1]).inDays == 1) {
        streak++;
        if (streak > best) best = streak;
      } else {
        streak = 1;
      }
    }
    return {'current': current, 'best': best};
  }

  // ── Heatmap generation (4 weeks × 7 days ending today) ────────────────────
  List<List<int>> _computeHeatmap(List<TaskModel> all) {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Start 27 days ago (4 full weeks ending today)
    final start = today.subtract(const Duration(days: 27));

    return List.generate(4, (week) {
      return List.generate(7, (day) {
        final d = start.add(Duration(days: week * 7 + day));
        final count = all
            .where((t) =>
                t.date.year == d.year &&
                t.date.month == d.month &&
                t.date.day == d.day)
            .length;
        if (count == 0) return 0;
        if (count <= 1) return 1;
        if (count <= 3) return 2;
        return 3;
      });
    });
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(_currentYear + 1, 12, 31),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskListProvider);
    final tasks = _filterTasks(allTasks);
    final summary = _computeSummary(tasks);
    final weekBars = _computeWeeklyBars(allTasks); // Always week view for bars
    final cats = _computeCategories(tasks);
    final streak = _computeStreak(allTasks);
    final heatmap = _computeHeatmap(allTasks);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFilterTabs(context),
          const SizedBox(height: 12),
          _buildSubFilter(context, card),
          const SizedBox(height: 24),
          _buildSummaryRow(context, card, summary),
          const SizedBox(height: 24),
          _buildBarChart(context, card, weekBars),
          const SizedBox(height: 24),
          _buildCategoryBreakdown(context, card, cats),
          const SizedBox(height: 24),
          _buildStreak(context, card, streak),
          const SizedBox(height: 24),
          _buildHeatmap(context, card, heatmap),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Filter Type Tabs ──────────────────────────────────────────────────────
  Widget _buildFilterTabs(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? darkCard : lightCard;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: List.generate(_filterLabels.length, (i) {
          final active = _filterType == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filterType = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: primary.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_filterIcons[i],
                        size: 18, color: active ? Colors.white : primary),
                    const SizedBox(height: 4),
                    Text(_filterLabels[i],
                        style: TextStyle(
                            color: active ? Colors.white : primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSubFilter(BuildContext context, Color card) {
    switch (_filterType) {
      case 1:
        return _buildMonthFilter(context, card);
      case 2:
        return _buildYearFilter(context, card);
      case 3:
        return _buildRangeFilter(context, card);
      default:
        return _buildWeekLabel(context, card);
    }
  }

  Widget _buildWeekLabel(BuildContext context, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.today_rounded, size: 16, color: primary),
        const SizedBox(width: 8),
        Text('Current Week',
            style: TextStyle(
                color: primary, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    );
  }

  Widget _buildYearFilter(BuildContext context, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navButton(context, Icons.chevron_left_rounded,
              () => setState(() => _selectedYear--),
              disabled: _selectedYear <= 2020),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_currentYear - 2020 + 1, (i) {
                  final year = 2020 + i;
                  final active = _selectedYear == year;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedYear = year),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            active ? primary : primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$year',
                          style: TextStyle(
                              color: active ? Colors.white : primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  );
                }),
              ),
            ),
          ),
          _navButton(context, Icons.chevron_right_rounded,
              () => setState(() => _selectedYear++),
              disabled: _selectedYear >= _currentYear),
        ],
      ),
    );
  }

  Widget _buildMonthFilter(BuildContext context, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navButton(context, Icons.chevron_left_rounded,
                () => setState(() => _selectedYear--),
                disabled: _selectedYear <= 2020),
            Text('$_selectedYear',
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.w800, fontSize: 16)),
            _navButton(context, Icons.chevron_right_rounded,
                () => setState(() => _selectedYear++),
                disabled: _selectedYear >= _currentYear),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(12, (i) {
            final month = i + 1;
            final active = _selectedMonth == month;
            final disabled =
                _selectedYear == _currentYear && month > _currentMonth;
            return GestureDetector(
              onTap: disabled
                  ? null
                  : () => setState(() => _selectedMonth = month),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: disabled
                      ? primary.withValues(alpha: 0.04)
                      : active
                          ? primary
                          : primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_monthNames[i],
                    style: TextStyle(
                        color: disabled
                            ? primary.withValues(alpha: 0.3)
                            : active
                                ? Colors.white
                                : primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildRangeFilter(BuildContext context, Color card) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? darkTextSecondary : lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _buildDateChip(context,
                  label: 'Start Date',
                  value: _startDate != null ? _fmtDate(_startDate!) : null,
                  icon: Icons.calendar_today_rounded,
                  primary: primary,
                  textSec: textSec,
                  onTap: () => _pickDateRange(context))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: textSec),
          ),
          Expanded(
              child: _buildDateChip(context,
                  label: 'End Date',
                  value: _endDate != null ? _fmtDate(_endDate!) : null,
                  icon: Icons.event_rounded,
                  primary: primary,
                  textSec: textSec,
                  onTap: () => _pickDateRange(context))),
        ]),
        if (_startDate != null && _endDate != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text('${_endDate!.difference(_startDate!).inDays + 1} days',
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
              GestureDetector(
                onTap: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
                child: const Text('Clear',
                    style: TextStyle(
                        color: statusOverdue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
        if (_startDate == null || _endDate == null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pickDateRange(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.date_range_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                Text('Tap to pick date range',
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildDateChip(BuildContext context,
      {required String label,
      required String? value,
      required IconData icon,
      required Color primary,
      required Color textSec,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: value != null
              ? primary.withValues(alpha: 0.12)
              : primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value != null
                  ? primary.withValues(alpha: 0.4)
                  : primary.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: textSec, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(icon, size: 12, color: primary),
            const SizedBox(width: 4),
            Flexible(
                child: Text(value ?? 'Select',
                    style: TextStyle(
                        color: value != null ? primary : textSec,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
          ]),
        ]),
      ),
    );
  }

  Widget _navButton(BuildContext context, IconData icon, VoidCallback onTap,
      {bool disabled = false}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: disabled
                ? primary.withValues(alpha: 0.05)
                : primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 20,
              color: disabled ? primary.withValues(alpha: 0.3) : primary),
        ),
      ),
    );
  }

  // ── Summary Row ───────────────────────────────────────────────────────────
  Widget _buildSummaryRow(
      BuildContext context, Color card, Map<String, dynamic> summary) {
    final items = [
      {
        'value': '${summary['pct']}%',
        'label': 'Completion',
        'color': statusCompleted,
      },
      {
        'value': '${summary['done']}',
        'label': 'Done',
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'value': '${summary['overdue']}',
        'label': 'Overdue',
        'color': statusOverdue,
      },
    ];

    return Row(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              Text(item['value'] as String,
                  style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: item['color'] as Color)),
              Text(item['label'] as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Bar Chart ─────────────────────────────────────────────────────────────
  Widget _buildBarChart(
      BuildContext context, Color card, List<Map<String, dynamic>> bars) {
    final primary = Theme.of(context).colorScheme.primary;
    final textSecCt = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text('Daily Completion — $_periodLabel',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 16),
        ...bars.map((stat) {
          final pct = stat['percent'] as double;
          final total = stat['total'] as int;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                  width: 30,
                  child: Text(stat['day'] as String,
                      style: TextStyle(
                          color: textSecCt,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 14,
                    backgroundColor: primary.withValues(alpha: 0.12),
                    color: total == 0
                        ? primary.withValues(alpha: 0.15)
                        : pct < 0.5
                            ? statusRisk
                            : pct < 0.8
                                ? primary.withValues(alpha: 0.7)
                                : statusCompleted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38,
                child: Text(total == 0 ? '—' : '${(pct * 100).round()}%',
                    style: TextStyle(
                        color: textSecCt,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                    textAlign: TextAlign.right),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Category Breakdown ────────────────────────────────────────────────────
  Widget _buildCategoryBreakdown(
      BuildContext context, Color card, List<Map<String, dynamic>> cats) {
    final textSec = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.donut_large_rounded,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('Top Categories',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        if (cats.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No tasks in this period',
                  style: TextStyle(color: textSec, fontSize: 13)),
            ),
          )
        else
          ...cats.map((stat) {
            final pct = stat['percent'] as double;
            final color = stat['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                SizedBox(
                    width: 70,
                    child: Text(stat['label'] as String,
                        style: TextStyle(
                            color: textSec,
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        backgroundColor: color.withValues(alpha: 0.12),
                        color: color),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(pct * 100).round()}%',
                    style: TextStyle(
                        color: textSec,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
            );
          }),
      ]),
    );
  }

  // ── Streak ────────────────────────────────────────────────────────────────
  Widget _buildStreak(
      BuildContext context, Color card, Map<String, int> streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('Current Streak',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text('${streak['current']} Days',
                style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: statusRisk)),
          ]),
        ),
        Container(
            width: 1, height: 60, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(width: 20),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Best Streak',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('${streak['best']} Days',
                style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary)),
          ]),
        ),
      ]),
    );
  }

  // ── Heatmap ───────────────────────────────────────────────────────────────
  Widget _buildHeatmap(
      BuildContext context, Color card, List<List<int>> heatmap) {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final primary = Theme.of(context).colorScheme.primary;
    final textSec = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.grid_view_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Text('Activity — Last 4 Weeks',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayLabels
              .map((d) => SizedBox(
                    width: 28,
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        ...heatmap.map((week) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week.map((activity) {
                  final opacity = activity == 0
                      ? 0.07
                      : activity == 1
                          ? 0.3
                          : activity == 2
                              ? 0.6
                              : 0.9;
                  return Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: activity == 0
                          ? primary.withValues(alpha: 0.07)
                          : primary.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }).toList(),
              ),
            )),
        const SizedBox(height: 10),
        Row(children: [
          Text('Less', style: TextStyle(color: textSec, fontSize: 11)),
          const SizedBox(width: 6),
          ...List.generate(
              4,
              (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color:
                          primary.withValues(alpha: [0.07, 0.3, 0.6, 0.9][i]),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
          Text('More', style: TextStyle(color: textSec, fontSize: 11)),
        ]),
      ]),
    );
  }
}
