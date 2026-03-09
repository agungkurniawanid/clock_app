import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../providers/app_providers.dart';
import '../widgets/swipeable_card.dart';
import '../widgets/empty_state_widget.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

const _tabs = ['All', 'In Progress', 'Upcoming', 'Risk', 'Overdue', 'Done'];

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(taskTabIndexProvider);
    final filteredTasks = ref.watch(filteredTasksProvider);
    final query = ref.watch(taskSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedules'),
        actions: [
          const _FilterButton(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (v) =>
                      ref.read(taskSearchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search schedules...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => ref
                                .read(taskSearchQueryProvider.notifier)
                                .state = '',
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
                        onTap: () =>
                            ref.read(taskTabIndexProvider.notifier).state = i,
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
      body: filteredTasks.isEmpty
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
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: filteredTasks.length,
              itemBuilder: (ctx, i) {
                final task = filteredTasks[i];
                return SwipeableCard(
                  task: task,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(task: task)),
                  ),
                  onComplete: () =>
                      ref.read(taskListProvider.notifier).markComplete(task.id),
                  onDelete: () =>
                      ref.read(taskListProvider.notifier).deleteTask(task.id),
                );
              },
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
