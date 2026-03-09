import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../widgets/swipeable_card.dart';
import '../widgets/empty_state_widget.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

const _tabs = ['All', 'In Progress', 'Upcoming', 'Risk', 'Overdue', 'Done'];

// ── Marker class for empty day rows ─────────────────────────────────────────
class _EmptyDay {
  const _EmptyDay();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build the flat items list for the "all dates" view ───────────────────
  List<dynamic> _buildAllDateItems(List<TaskModel> tasks) {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime startDate = today;
    DateTime endDate = today.add(const Duration(days: 30));

    if (tasks.isNotEmpty) {
      for (final t in tasks) {
        final d = DateUtils.dateOnly(t.date);
        if (d.isBefore(startDate)) startDate = d;
        if (d.isAfter(endDate)) endDate = d;
      }
    }

    final Map<DateTime, List<TaskModel>> grouped = {};
    for (final task in tasks) {
      final day = DateUtils.dateOnly(task.date);
      grouped.putIfAbsent(day, () => []).add(task);
    }

    final List<dynamic> items = [];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      items.add(current);
      final dayTasks = grouped[current];
      if (dayTasks != null && dayTasks.isNotEmpty) {
        items.addAll(dayTasks);
      } else {
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

    // Determine if we should show the all-dates calendar view
    final showAllDates = tabIndex == 0 && query.isEmpty;

    if (showAllDates) {
      _allItems = _buildAllDateItems(filteredTasks);
      if (!_didInitialScroll) {
        _didInitialScroll = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToToday();
        });
      }
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
                    // Reset initial scroll flag so we re-scroll to today
                    // when user clears search and returns to all-dates view
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
                      return GestureDetector(
                        onTap: () {
                          ref.read(taskTabIndexProvider.notifier).state = i;
                          // Re-trigger scroll to today when switching back to All
                          if (i == 0) _didInitialScroll = false;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                            _tabs[i],
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
      body: showAllDates
          ? _buildAllDatesListView(context, _allItems)
          : filteredTasks.isEmpty
              ? EmptyStateWidget(
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
                )
              : _buildGroupedList(context, filteredTasks),
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

        if (item is _EmptyDay) {
          return Padding(
            padding:
                const EdgeInsets.only(left: 72, right: 16, bottom: 12, top: 2),
            child: Text(
              'Tidak ada tugas untuk hari ini',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.33),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
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
