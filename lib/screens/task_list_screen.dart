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
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
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
                const SizedBox(height: 8),
                // Priority Sort Chips
                const _PrioritySortBar(),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTaskScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FilterSheet(),
    );
  }
}

class _PrioritySortBar extends ConsumerWidget {
  const _PrioritySortBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(taskPriorityFilterProvider);
    final sortAsc = ref.watch(taskSortAscendingProvider);
    final options = <String, TaskPriority?>{
      'All': null,
      'Low': TaskPriority.low,
      'Medium': TaskPriority.medium,
      'High': TaskPriority.high,
    };

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final label = options.keys.elementAt(i);
                final value = options.values.elementAt(i);
                final active = selected == value;
                Color chipColor;
                if (!active) {
                  chipColor = Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1);
                } else if (value == TaskPriority.high) {
                  chipColor = const Color(0xFFE53E3E);
                } else if (value == TaskPriority.medium) {
                  chipColor = const Color(0xFFDD6B20);
                } else if (value == TaskPriority.low) {
                  chipColor = const Color(0xFF38A169);
                } else {
                  chipColor = Theme.of(context).colorScheme.primary;
                }
                return GestureDetector(
                  onTap: () => ref
                      .read(taskPriorityFilterProvider.notifier)
                      .state = value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                ref.read(taskSortAscendingProvider.notifier).state = !sortAsc,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: sortAsc ? 1.0 : 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sortAsc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Date',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  String _selectedStatus = 'All';
  String _selectedMode = 'Any';
  String _selectedRepeat = 'Any';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Filter Schedules',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          _filterSection(
              context,
              'Status',
              ['All', 'In Progress', 'Todo', 'At Risk', 'Overdue', 'Done'],
              _selectedStatus,
              (v) => setState(() => _selectedStatus = v)),
          const SizedBox(height: 16),
          _filterSection(
              context,
              'Alarm Mode',
              ['Any', 'Music Alarm', 'Notification'],
              _selectedMode,
              (v) => setState(() => _selectedMode = v)),
          const SizedBox(height: 16),
          _filterSection(
              context,
              'Repeat',
              ['Any', 'None', 'Daily', 'Weekly', 'Monthly'],
              _selectedRepeat,
              (v) => setState(() => _selectedRepeat = v)),
          const SizedBox(height: 24),
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
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterSection(BuildContext context, String label,
      List<String> options, String selected, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
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
}
