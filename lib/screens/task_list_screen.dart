import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../models/birthday_model.dart';
import '../providers/app_providers.dart';
import '../data/global_events.dart';
import '../services/storage_service.dart';
import '../widgets/swipeable_card.dart';
import '../widgets/empty_state_widget.dart';
import 'add_task_screen.dart';
import 'birthday_screen.dart';
import 'task_detail_screen.dart';

const _tabs = [
  'All',
  'In Progress',
  'Upcoming',
  'Risk',
  'Overdue',
  'Done',
  'Birthday',
];

// ── Marker class for empty day rows ─────────────────────────────────────────
class _EmptyDay {
  const _EmptyDay();
}

// ── Marker class for birthday occurrences in the All tab ────────────────────
class _BirthdayItem {
  final BirthdayEntry entry;
  const _BirthdayItem(this.entry);
}

// ─── Task List Screen ─────────────────────────────────────────────────────────

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todayKey = GlobalKey();
  List<dynamic> _allItems = const [];
  bool _didInitialScroll = false;
  // Badge is visible whenever user enters this tab (unless permanently dismissed)
  bool _badgeVisible = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build the flat items list for the "all dates" view ───────────────────
  List<dynamic> _buildAllDateItems(
    List<TaskModel> tasks,
    List<BirthdayEntry> birthdays, {
    List<GlobalEvent> apiHolidays = const [],
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime startDate = today;
    DateTime endDate = today.add(const Duration(days: 30));

    // Only expand the window for non-repeating tasks; repeating tasks
    // are rendered within the fixed window based on their recurrence pattern.
    if (tasks.isNotEmpty) {
      for (final t in tasks) {
        if (t.repeat == RepeatType.none) {
          final d = DateUtils.dateOnly(t.date);
          if (d.isBefore(startDate)) startDate = d;
          if (d.isAfter(endDate)) endDate = d;
        }
      }
    }

    // Build grouped map by expanding each task's repeat occurrences in range.
    final Map<DateTime, List<TaskModel>> grouped = {};
    var d = startDate;
    while (!d.isAfter(endDate)) {
      for (final task in tasks) {
        if (task.occursOnDate(d)) {
          grouped.putIfAbsent(d, () => []).add(task);
        }
      }
      d = d.add(const Duration(days: 1));
    }

    final List<dynamic> items = [];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      items.add(current);

      // Global events for this date (cultural + API-fetched holidays)
      final events = getEventsForDate(current, extra: apiHolidays);
      for (final ev in events) {
        items.add(ev);
      }

      // Birthday entries on this date
      for (final b in birthdays) {
        if (b.month == current.month && b.day == current.day) {
          items.add(_BirthdayItem(b));
        }
      }

      final dayTasks = grouped[current];
      if (dayTasks != null && dayTasks.isNotEmpty) {
        items.addAll(dayTasks);
      } else if (events.isEmpty &&
          !birthdays
              .any((b) => b.month == current.month && b.day == current.day)) {
        items.add(const _EmptyDay());
      }
      current = current.add(const Duration(days: 1));
    }
    return items;
  }

  // ── Scroll to today's section ────────────────────────────────────────────
  void _scrollToToday() {
    if (!_scrollController.hasClients) return;

    // Try direct context-based scroll first (widget already visible)
    final ctx = _todayKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
      return;
    }

    // Estimate offset by counting items above today
    int itemsBefore = 0;
    for (final item in _allItems) {
      if (item is DateTime && DateUtils.isSameDay(item, DateTime.now())) break;
      itemsBefore++;
    }
    // Each date header ≈ 76px, task card ≈ 100px, empty row ≈ 44px
    double estimatedOffset = 0;
    for (int i = 0; i < itemsBefore && i < _allItems.length; i++) {
      final item = _allItems[i];
      if (item is DateTime) {
        estimatedOffset += 76.0;
      } else if (item is TaskModel) {
        estimatedOffset += 100.0;
      } else {
        estimatedOffset += 44.0;
      }
    }

    _scrollController.animateTo(
      estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(taskTabIndexProvider);
    final filteredTasks = ref.watch(filteredTasksProvider);
    final query = ref.watch(taskSearchQueryProvider);
    final birthdays = ref.watch(birthdayListProvider);
    final permanentlyDismissed =
        ref.watch(birthdayBadgePermanentlyDismissedProvider);
    // API-fetched public holidays (empty list while loading, holidays once loaded)
    final apiHolidays =
        ref.watch(holidayProvider).valueOrNull?.holidays ?? const [];

    // Reset badge visibility when user navigates back to this tab
    ref.listen<int>(navIndexProvider, (prev, next) {
      if (next == 1 && prev != 1) {
        if (mounted) setState(() => _badgeVisible = true);
      }
    });

    final showBadge = _badgeVisible && !permanentlyDismissed;

    // Determine if we should show the all-dates calendar view
    final showAllDates = tabIndex == 0 && query.isEmpty;

    if (showAllDates) {
      _allItems = _buildAllDateItems(filteredTasks, birthdays,
          apiHolidays: apiHolidays);
      if (!_didInitialScroll) {
        _didInitialScroll = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToToday();
        });
      }
    }

    Widget bodyContent;
    if (tabIndex == 6) {
      // Birthday tab
      bodyContent = _buildBirthdayTabView(context, birthdays);
    } else if (showAllDates) {
      bodyContent = _buildAllDatesListView(context, _allItems);
    } else if (filteredTasks.isEmpty) {
      bodyContent = EmptyStateWidget(
        icon: Icons.event_busy_rounded,
        title: tabIndex == 3 ? 'No At-Risk Tasks' : 'Nothing Here',
        subtitle: tabIndex == 3
            ? 'Great! You have no tasks at risk right now.'
            : 'Add a new schedule to get started.',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTaskScreen()),
        ),
        actionLabel: 'Add Schedule',
      );
    } else {
      bodyContent = _buildGroupedList(context, filteredTasks);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedules'),
        actions: const [
          _FilterButton(),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (v) {
                    ref.read(taskSearchQueryProvider.notifier).state = v;
                    if (v.isEmpty) _didInitialScroll = false;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search schedules...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              ref.read(taskSearchQueryProvider.notifier).state =
                                  '';
                              _didInitialScroll = false;
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                // Tab Bar
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final active = tabIndex == i;
                      final isBirthdayTab = i == 6;
                      final tabColor = isBirthdayTab
                          ? const Color(0xFFFF6B9D)
                          : Theme.of(context).colorScheme.primary;
                      return GestureDetector(
                        onTap: () {
                          ref.read(taskTabIndexProvider.notifier).state = i;
                          if (i == 0) _didInitialScroll = false;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? tabColor
                                : tabColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: isBirthdayTab && !active
                                ? Border.all(
                                    color: tabColor.withValues(alpha: 0.4),
                                    width: 1.2)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isBirthdayTab) ...[
                                const Text('🎂',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _tabs[i],
                                style: TextStyle(
                                  color: active ? Colors.white : tabColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: showAllDates
          ? FloatingActionButton.small(
              onPressed: _scrollToToday,
              tooltip: 'Go to today',
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.today_rounded,
                color: Colors.white,
                size: 20,
              ),
            )
          : null,
      body: Column(
        children: [
          if (showBadge)
            _BirthdayInfoBadge(
              onClose: () => setState(() => _badgeVisible = false),
              onDismissForever: () async {
                setState(() => _badgeVisible = false);
                ref
                    .read(birthdayBadgePermanentlyDismissedProvider.notifier)
                    .state = true;
                await StorageService.saveBirthdayBadgeDismissed(true);
              },
              onGoToSettings: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BirthdayScreen()),
              ),
            ),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  // ── All-dates Google Calendar-style list ─────────────────────────────────
  Widget _buildAllDatesListView(BuildContext context, List<dynamic> items) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];

        if (item is DateTime) {
          final isToday = DateUtils.isSameDay(item, DateTime.now());
          return _DateGroupHeader(
            key: isToday ? _todayKey : null,
            date: item,
          );
        }

        if (item is GlobalEvent) {
          return Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: _GlobalEventCard(event: item),
          );
        }

        if (item is _BirthdayItem) {
          return Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: _BirthdayMiniCard(entry: item.entry),
          );
        }

        if (item is _EmptyDay) {
          return Padding(
            padding:
                const EdgeInsets.only(left: 72, right: 16, bottom: 12, top: 2),
            child: Text(
              'Tidak ada tugas untuk hari ini',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF171717),
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
            ),
          );
        }

        final task = item as TaskModel;
        return Padding(
          padding: const EdgeInsets.only(left: 72, right: 16),
          child: SwipeableCard(
            task: task,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
            ),
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddTaskScreen(editTask: task)),
            ),
            onComplete: () =>
                ref.read(taskListProvider.notifier).markComplete(task.id),
            onDelete: () =>
                ref.read(taskListProvider.notifier).deleteTask(task.id),
          ),
        );
      },
    );
  }

  // ── Birthday tab view ─────────────────────────────────────────────────────
  Widget _buildBirthdayTabView(
      BuildContext context, List<BirthdayEntry> birthdays) {
    if (birthdays.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.cake_rounded,
        title: 'Belum Ada Data Ulang Tahun',
        subtitle:
            'Tambahkan ulang tahun Anda, keluarga, atau teman di halaman Ulang Tahun.',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BirthdayScreen()),
        ),
        actionLabel: 'Buka Ulang Tahun',
      );
    }

    // Sort: find next occurrence of each birthday
    final now = DateTime.now();
    final sorted = birthdays.toList()
      ..sort((a, b) {
        final aNext = _nextOccurrence(a.month, a.day, now);
        final bNext = _nextOccurrence(b.month, b.day, now);
        return aNext.compareTo(bNext);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => _BirthdayEventCard(
        entry: sorted[i],
        nextDate: _nextOccurrence(sorted[i].month, sorted[i].day, now),
      ),
    );
  }

  static DateTime _nextOccurrence(int month, int day, DateTime from) {
    final thisYear = DateTime(from.year, month, day);
    if (!thisYear.isBefore(DateUtils.dateOnly(from))) return thisYear;
    // If birthday already passed this year, return next year's
    final dayInMonth = DateTime(from.year + 1, month + 1, 0).day;
    return DateTime(from.year + 1, month, day.clamp(1, dayInMonth));
  }

  // ── Regular grouped list for non-All tabs ────────────────────────────────
  Widget _buildGroupedList(BuildContext context, List<TaskModel> tasks) {
    final Map<DateTime, List<TaskModel>> grouped = {};
    for (final task in tasks) {
      final day = DateUtils.dateOnly(task.date);
      grouped.putIfAbsent(day, () => []).add(task);
    }
    final sortedDates = grouped.keys.toList()..sort();
    final List<dynamic> items = [];
    for (final date in sortedDates) {
      items.add(date);
      items.addAll(grouped[date]!);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is DateTime) {
          return _DateGroupHeader(date: item);
        }
        final task = item as TaskModel;
        return Padding(
          padding: const EdgeInsets.only(left: 72, right: 16),
          child: SwipeableCard(
            task: task,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
            ),
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddTaskScreen(editTask: task)),
            ),
            onComplete: () =>
                ref.read(taskListProvider.notifier).markComplete(task.id),
            onDelete: () =>
                ref.read(taskListProvider.notifier).deleteTask(task.id),
          ),
        );
      },
    );
  }
}

// ─── Date Group Header (Google Calendar style) ─────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  final DateTime date;
  const _DateGroupHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthNames = [
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
    final dayName = dayNames[date.weekday - 1];
    final monthName = monthNames[date.month - 1];
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final primary = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    date.day.toString(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isToday
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayName,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: isToday
                        ? primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName ${date.year}',
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF171717),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Filter Button (AppBar Action) ─────────────────────────────────────────────

class _FilterButton extends ConsumerWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = ref.watch(taskPriorityFilterProvider);
    final sortAsc = ref.watch(taskSortAscendingProvider);
    final hasFilter = priority != null || !sortAsc;

    return GestureDetector(
      onTap: () => _showFilterSheet(context, ref),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: hasFilter
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: hasFilter ? 0.0 : 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: hasFilter
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Filter',
                  style: TextStyle(
                    color: hasFilter
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (hasFilter)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _FilterSheet(),
    );
  }
}

// ─── Filter Bottom Sheet ────────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TaskPriority? _selectedPriority;
  late bool _sortAsc;
  String _selectedMode = 'Any';
  String _selectedRepeat = 'Any';

  @override
  void initState() {
    super.initState();
    _selectedPriority = ref.read(taskPriorityFilterProvider);
    _sortAsc = ref.read(taskSortAscendingProvider);
  }

  void _resetFilters() {
    setState(() {
      _selectedPriority = null;
      _sortAsc = true;
      _selectedMode = 'Any';
      _selectedRepeat = 'Any';
    });
  }

  void _applyFilters() {
    ref.read(taskPriorityFilterProvider.notifier).state = _selectedPriority;
    ref.read(taskSortAscendingProvider.notifier).state = _sortAsc;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 28 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Schedules',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Priority
          _buildPrioritySection(),
          const SizedBox(height: 18),

          // Date Sort
          _buildDateSortSection(),
          const SizedBox(height: 18),

          // Alarm Mode
          _buildChipSection(
            'Alarm Mode',
            ['Any', 'Music Alarm', 'Notification'],
            _selectedMode,
            (v) => setState(() => _selectedMode = v),
          ),
          const SizedBox(height: 18),

          // Repeat
          _buildChipSection(
            'Repeat',
            ['Any', 'None', 'Daily', 'Weekly', 'Monthly'],
            _selectedRepeat,
            (v) => setState(() => _selectedRepeat = v),
          ),
          const SizedBox(height: 24),

          // Action Buttons
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
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySection() {
    final options = <String, TaskPriority?>{
      'All': null,
      'Low': TaskPriority.low,
      'Medium': TaskPriority.medium,
      'High': TaskPriority.high,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Priority'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((e) {
            final active = _selectedPriority == e.value;
            Color chipColor;
            if (!active) {
              chipColor =
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
            } else if (e.value == TaskPriority.high) {
              chipColor = const Color(0xFFE53E3E);
            } else if (e.value == TaskPriority.medium) {
              chipColor = const Color(0xFFDD6B20);
            } else if (e.value == TaskPriority.low) {
              chipColor = const Color(0xFF38A169);
            } else {
              chipColor = Theme.of(context).colorScheme.primary;
            }
            return GestureDetector(
              onTap: () => setState(() => _selectedPriority = e.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  e.key,
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

  Widget _buildDateSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Sort by Start Date'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _dateSortChip(
              label: 'Oldest First',
              icon: Icons.arrow_upward_rounded,
              isActive: _sortAsc,
              onTap: () => setState(() => _sortAsc = true),
            ),
            _dateSortChip(
              label: 'Newest First',
              icon: Icons.arrow_downward_rounded,
              isActive: !_sortAsc,
              onTap: () => setState(() => _sortAsc = false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateSortChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSection(
    String label,
    List<String> options,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = selected == o;
            return GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
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
                  o,
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
    );
  }
}

// ─── Global Event Card (shown in All tab timeline) ────────────────────────────

class _GlobalEventCard extends StatelessWidget {
  final GlobalEvent event;
  const _GlobalEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: event.color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: event.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Libur Nasional',
              style: TextStyle(
                color: event.color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Birthday Mini Card (shown in All tab timeline) ───────────────────────────

class _BirthdayMiniCard extends StatelessWidget {
  final BirthdayEntry entry;
  const _BirthdayMiniCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            entry.color.withValues(alpha: 0.18),
            const Color(0xFFFF6B9D).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: entry.color.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎂', style: TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 Ulang Tahun ${entry.name}!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: entry.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.typeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: entry.color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Birthday 🎂',
              style: TextStyle(
                color: entry.color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Birthday Event Card (Birthday tab, full card) ────────────────────────────

class _BirthdayEventCard extends StatelessWidget {
  final BirthdayEntry entry;
  final DateTime nextDate;

  const _BirthdayEventCard({required this.entry, required this.nextDate});

  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(nextDate, today);
    final tomorrow = today.add(const Duration(days: 1));
    final isTomorrow = DateUtils.isSameDay(nextDate, tomorrow);
    final daysLeft = nextDate.difference(today).inDays;

    String dateLabel;
    if (isToday) {
      dateLabel = '🎉 Hari ini!';
    } else if (isTomorrow) {
      dateLabel = 'Besok';
    } else {
      dateLabel =
          '${entry.day} ${_monthNames[entry.month - 1]} · $daysLeft hari lagi';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? entry.color : entry.color.withValues(alpha: 0.4),
          width: isToday ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: entry.color.withValues(alpha: isToday ? 0.25 : 0.1),
            blurRadius: isToday ? 14 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with cake icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    entry.color,
                    entry.color.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: entry.color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🎂', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.typeLabel,
                          style: TextStyle(
                            color: entry.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isToday
                                  ? entry.color
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Day number badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isToday ? entry.color : entry.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${entry.day}',
                    style: TextStyle(
                      color: isToday ? Colors.white : entry.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1,
                    ),
                  ),
                  Text(
                    [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'Mei',
                      'Jun',
                      'Jul',
                      'Ags',
                      'Sep',
                      'Okt',
                      'Nov',
                      'Des'
                    ][entry.month - 1],
                    style: TextStyle(
                      color: isToday
                          ? Colors.white.withValues(alpha: 0.85)
                          : entry.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Birthday Info Badge ──────────────────────────────────────────────────────

class _BirthdayInfoBadge extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onDismissForever;
  final VoidCallback onGoToSettings;

  const _BirthdayInfoBadge({
    required this.onClose,
    required this.onDismissForever,
    required this.onGoToSettings,
  });

  @override
  Widget build(BuildContext context) {
    const birthdayColor = Color(0xFFFF6B9D);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            birthdayColor.withValues(alpha: 0.15),
            const Color(0xFF7B6EF6).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: birthdayColor.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎂', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitur Ulang Tahun Tersedia! 🎉',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: birthdayColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Anda bisa menambahkan data tanggal ulang tahun Anda dan teman-teman di halaman Ulang Tahun. Ulang tahun akan muncul di tab All dan tab Birthday.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onGoToSettings,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: birthdayColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Isi Sekarang',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDismissForever,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: birthdayColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: birthdayColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Sudah diisi ✓',
                          style: TextStyle(
                            color: birthdayColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close button
          GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
