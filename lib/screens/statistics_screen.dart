import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/task_model.dart';
import '../models/pomodoro_model.dart';
import '../theme/app_colors.dart';
import '../utils/dialog_utils.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  int _filterType = 0; // 0=Week, 1=Month, 2=Year, 3=Range

  final int _currentYear = DateTime.now().year;
  final int _currentMonth = DateTime.now().month;

  late int _selectedYear;
  late int _selectedMonth;

  DateTime? _startDate;
  DateTime? _endDate;

  late TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              width: 3.0,
              color: isDark ? darkPrimary : lightPrimary,
            ),
            insets: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
          tabs: const [
            Tab(text: 'Tasks', icon: Icon(Icons.task_alt_rounded, size: 20)),
            Tab(text: 'Pomodoro', icon: Icon(Icons.timer_outlined, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tasks Tab
          ListView(
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
          // Pomodoro Tab
          _buildPomodoroTab(context, isDark, card),
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

  // ── Pomodoro Tab ──────────────────────────────────────────────────────────
  Widget _buildPomodoroTab(BuildContext context, bool isDark, Color card) {
    final pomodoroState = ref.watch(pomodoroProvider);
    final allSessions = pomodoroState.allSessions;
    final filteredSessions = _filterPomodoroSessions(allSessions);
    final pomodoroSummary = _computePomodoroSummary(filteredSessions);
    final weeklyPomodoros = _computeWeeklyPomodoros(allSessions);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildFilterTabs(context),
        const SizedBox(height: 12),
        _buildSubFilter(context, card),
        const SizedBox(height: 24),
        _buildPomodoroSummaryRow(context, card, pomodoroSummary),
        const SizedBox(height: 24),
        _buildPomodoroWeeklyChart(context, card, weeklyPomodoros),
        const SizedBox(height: 24),
        _buildPomodoroSessionsList(context, card, filteredSessions),
        const SizedBox(height: 40),
      ],
    );
  }

  List<PomodoroSession> _filterPomodoroSessions(
      List<PomodoroSession> sessions) {
    final now = DateTime.now();
    switch (_filterType) {
      case 0: // This week
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return sessions.where((s) {
          return !s.startTime.isBefore(start) && !s.startTime.isAfter(end);
        }).toList();

      case 1: // Month
        return sessions
            .where((s) =>
                s.startTime.year == _selectedYear &&
                s.startTime.month == _selectedMonth)
            .toList();

      case 2: // Year
        return sessions
            .where((s) => s.startTime.year == _selectedYear)
            .toList();

      case 3: // Range
        if (_startDate == null || _endDate == null) return sessions;
        final s =
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final e = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return sessions.where((session) {
          return !session.startTime.isBefore(s) &&
              !session.startTime.isAfter(e);
        }).toList();

      default:
        return sessions;
    }
  }

  Map<String, dynamic> _computePomodoroSummary(List<PomodoroSession> sessions) {
    final completedWork = sessions
        .where((s) => s.type == PomodoroSessionType.work && s.completed)
        .length;
    final completedBreaks = sessions
        .where((s) =>
            (s.type == PomodoroSessionType.shortBreak ||
                s.type == PomodoroSessionType.longBreak) &&
            s.completed)
        .length;
    final totalMinutes = sessions
        .where((s) => s.completed)
        .fold(0, (sum, s) => sum + s.durationMinutes);

    return {
      'work': completedWork,
      'breaks': completedBreaks,
      'minutes': totalMinutes,
    };
  }

  List<Map<String, dynamic>> _computeWeeklyPomodoros(
      List<PomodoroSession> sessions) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      final daySessions = sessions.where((s) {
        final sessionDay =
            DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        final targetDay = DateTime(day.year, day.month, day.day);
        return sessionDay == targetDay;
      }).toList();

      final completed = daySessions
          .where((s) => s.type == PomodoroSessionType.work && s.completed)
          .length;

      return {
        'day': dayNames[i],
        'count': completed,
      };
    });
  }

  Widget _buildPomodoroSummaryRow(
      BuildContext context, Color card, Map<String, dynamic> summary) {
    final items = [
      {
        'value': '${summary['work']}',
        'label': 'Work Sessions',
        'color': const Color(0xFFFF6B6B),
        'icon': Icons.work_outline,
      },
      {
        'value': '${summary['breaks']}',
        'label': 'Breaks',
        'color': const Color(0xFF4ECDC4),
        'icon': Icons.coffee_outlined,
      },
      {
        'value': '${summary['minutes']}',
        'label': 'Minutes',
        'color': const Color(0xFF7B6EF6),
        'icon': Icons.access_time,
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
              Icon(item['icon'] as IconData,
                  color: item['color'] as Color, size: 24),
              const SizedBox(height: 8),
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

  Widget _buildPomodoroWeeklyChart(
      BuildContext context, Color card, List<Map<String, dynamic>> data) {
    final primary = Theme.of(context).colorScheme.primary;
    final textSecCt = Theme.of(context).textTheme.bodyMedium?.color;
    final maxCount = data.fold<int>(0, (max, d) {
      final count = d['count'] as int;
      return count > max ? count : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Text('Weekly Sessions — $_periodLabel',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        ...data.map((stat) {
          final count = stat['count'] as int;
          final progress = maxCount > 0 ? count / maxCount : 0.0;
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
                    value: progress,
                    minHeight: 14,
                    backgroundColor:
                        const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                    color: count == 0
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.15)
                        : const Color(0xFFFF6B6B),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text('$count',
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

  Widget _buildPomodoroSessionsList(
      BuildContext context, Color card, List<PomodoroSession> sessions) {
    final primary = Theme.of(context).colorScheme.primary;
    final textSec = Theme.of(context).textTheme.bodyMedium?.color;

    // Sort sessions by start time (newest first)
    final sortedSessions = List<PomodoroSession>.from(sessions)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Text('Session History',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (sessions.isNotEmpty)
            TextButton.icon(
              onPressed: () => _showClearAllHistoryDialog(context),
              icon: Icon(Icons.delete_sweep_rounded, size: 18, color: primary),
              label: Text('Clear All',
                  style: TextStyle(color: primary, fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        if (sortedSessions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No sessions in this period',
                  style: TextStyle(color: textSec, fontSize: 13)),
            ),
          )
        else
          ...sortedSessions.take(20).map((session) {
            final typeColor = session.type == PomodoroSessionType.work
                ? const Color(0xFFFF6B6B)
                : (session.type == PomodoroSessionType.shortBreak
                    ? const Color(0xFF4ECDC4)
                    : const Color(0xFF95E1D3));

            final typeIcon = session.type == PomodoroSessionType.work
                ? Icons.work_outline
                : (session.type == PomodoroSessionType.shortBreak
                    ? Icons.coffee_outlined
                    : Icons.bed_outlined);

            final formattedTime = _formatSessionTime(session.startTime);
            final statusIcon = session.completed
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded;
            final statusColor =
                session.completed ? statusCompleted : statusOverdue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.typeLabel,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text('$formattedTime • ${session.durationMinutes} min',
                          style: TextStyle(color: textSec, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20),
                  color: textSec,
                  onPressed: () => _showDeleteSessionDialog(context, session),
                  tooltip: 'Delete session',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  String _formatSessionTime(DateTime dateTime) {
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
      'Dec',
    ];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${months[dateTime.month - 1]} ${dateTime.day}, $hour:$minute';
  }

  void _showDeleteSessionDialog(BuildContext context, PomodoroSession session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showScaleDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Session',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete this ${session.typeLabel.toLowerCase()} session?',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(pomodoroProvider.notifier).deleteSession(session);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Session deleted', style: GoogleFonts.poppins()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showClearAllHistoryDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showScaleDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete all pomodoro session history? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(pomodoroProvider.notifier).clearAllSessions();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('All sessions cleared',
                      style: GoogleFonts.poppins()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear All', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}
