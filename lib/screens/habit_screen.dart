import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit_model.dart';
import '../providers/app_providers.dart';
import 'add_habit_screen.dart';

class HabitScreen extends ConsumerStatefulWidget {
  const HabitScreen({super.key});

  @override
  ConsumerState<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends ConsumerState<HabitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddHabitScreen()),
              ),
              icon: Icon(Icons.add_task_rounded, color: primary, size: 20),
              label: Text(
                'New',
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'All Habits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayTab(),
          _AllHabitsTab(),
        ],
      ),
    );
  }
}

// ── Today Tab ──────────────────────────────────────────────────────────────────
class _TodayTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final habits = ref.watch(todayHabitsProvider);

    if (habits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text('No habits scheduled for today',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            SizedBox(height: 8),
            Text('Tap + to create your first habit',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        return _HabitTodayCard(habit: habits[i], date: today);
      },
    );
  }
}

// ── Today Card ─────────────────────────────────────────────────────────────────
class _HabitTodayCard extends ConsumerWidget {
  final HabitModel habit;
  final DateTime date;

  const _HabitTodayCard({required this.habit, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = habit.completionCountOn(date);
    final isComplete = habit.isCompletedOn(date);
    final progress = (count / habit.targetCount).clamp(0.0, 1.0);
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddHabitScreen(editHabit: habit)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Color strip
              Container(
                width: 5,
                height: 54,
                decoration: BoxDecoration(
                  color: habit.colorTag,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: isComplete
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: isComplete
                            ? onSurface.withValues(alpha: 0.45)
                            : onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 14,
                            color: habit.currentStreak > 0
                                ? Colors.orange
                                : onSurface.withValues(alpha: 0.35)),
                        const SizedBox(width: 3),
                        Text(
                          '${habit.currentStreak} day streak',
                          style: TextStyle(
                            fontSize: 12,
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: habit.colorTag.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            habit.categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: habit.colorTag,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: onSurface.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? Colors.green : primary),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Count button + target
              Column(
                children: [
                  Text(
                    '$count/${habit.targetCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => ref
                        .read(habitListProvider.notifier)
                        .toggleCompletion(habit.id, date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isComplete
                            ? Colors.green
                            : primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isComplete ? Colors.green : primary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isComplete ? Icons.check_rounded : Icons.add_rounded,
                        color: isComplete ? Colors.white : primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── All Habits Tab ─────────────────────────────────────────────────────────────
class _AllHabitsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHabits = ref.watch(habitListProvider);
    final active = allHabits.where((h) => !h.isArchived).toList();
    final archived = allHabits.where((h) => h.isArchived).toList();

    if (allHabits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Text('No habits yet',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            SizedBox(height: 8),
            Text('Tap + to create a habit',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader(context, 'Active (${active.length})'),
          const SizedBox(height: 8),
          ...active.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HabitListCard(habit: h),
              )),
        ],
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader(context, 'Archived (${archived.length})'),
          const SizedBox(height: 8),
          ...archived.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HabitListCard(habit: h, isArchived: true),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── List Card ──────────────────────────────────────────────────────────────────
class _HabitListCard extends ConsumerWidget {
  final HabitModel habit;
  final bool isArchived;

  const _HabitListCard({required this.habit, this.isArchived = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final streak = habit.currentStreak;
    final longest = habit.longestStreak;

    return Dismissible(
      key: Key(habit.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Habit'),
            content: Text('Delete "${habit.title}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) =>
          ref.read(habitListProvider.notifier).deleteHabit(habit.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Material(
        color: isArchived ? surface.withValues(alpha: 0.6) : surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddHabitScreen(editHabit: habit)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Color dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isArchived
                        ? habit.colorTag.withValues(alpha: 0.4)
                        : habit.colorTag,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isArchived
                              ? onSurface.withValues(alpha: 0.45)
                              : onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            habit.frequencyLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                                color: onSurface.withValues(alpha: 0.4)),
                          ),
                          Text(
                            habit.categoryLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 14,
                            color: streak > 0
                                ? Colors.orange
                                : onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 2),
                        Text(
                          '$streak',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'best $longest',
                      style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Archive/Unarchive button
                IconButton(
                  icon: Icon(
                    isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 20,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                  onPressed: () {
                    if (isArchived) {
                      ref
                          .read(habitListProvider.notifier)
                          .unarchiveHabit(habit.id);
                    } else {
                      ref
                          .read(habitListProvider.notifier)
                          .archiveHabit(habit.id);
                    }
                  },
                  tooltip: isArchived ? 'Unarchive' : 'Archive',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
