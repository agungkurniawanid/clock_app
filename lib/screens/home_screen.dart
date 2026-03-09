import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../widgets/clock_widget.dart';
import '../widgets/section_header.dart';
import '../widgets/task_card.dart';
import '../theme/app_colors.dart';
import '../models/task_model.dart';
import 'task_detail_screen.dart';
import 'alarm_screen.dart';
import 'signup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasks = ref.watch(taskListProvider);
    final summary = ref.watch(taskSummaryProvider);
    final todayTasks = ref.watch(todayTasksProvider);

    final upcomingTasks = tasks
        .where((t) =>
            t.status == TaskStatus.upcoming ||
            t.status == TaskStatus.todo ||
            t.status == TaskStatus.risk)
        .take(5)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          // Header fixed at top — covers the status bar area so content
          // scrolling up is clipped by the Column layout boundary here.
          _buildHeader(context, isDark),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clock
                        _buildClockCard(context, isDark),
                        // Summary Grid
                        _buildSummaryGrid(context, summary, ref),
                        const SizedBox(height: 20),
                        // Alarm Banner
                        _buildAlarmBanner(context, ref, tasks),
                        const SizedBox(height: 24),
                        // Today's Schedule
                        SectionHeader(
                          title: "Today's Schedule",
                          onSeeAll: () =>
                              ref.read(navIndexProvider.notifier).state = 1,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                // Horizontal scroll tasks
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: todayTasks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Center(
                              child: Text(
                                'No tasks scheduled for today 🎉',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: todayTasks.length,
                            itemBuilder: (ctx, i) => TaskCard(
                              task: todayTasks[i],
                              horizontal: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TaskDetailScreen(task: todayTasks[i])),
                              ),
                            ),
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: 'Upcoming This Week',
                          onSeeAll: () =>
                              ref.read(navIndexProvider.notifier).state = 1,
                        ),
                        const SizedBox(height: 12),
                        ...upcomingTasks.map((t) => TaskCard(
                              task: t,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(task: t)),
                              ),
                            )),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final now = DateTime.now();
    const greetings = {
      0: 'Good Night',
      6: 'Good Morning',
      12: 'Good Afternoon',
      18: 'Good Evening'
    };
    String greeting = 'Hello';
    for (final entry in greetings.entries) {
      if (now.hour >= entry.key) greeting = entry.value;
    }
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
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

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, User 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          const Text('Notifikasi'),
                        ],
                      ),
                      content: const Text(
                        'Fitur notifikasi masih dalam tahap pengembangan. '
                        'Nantikan pembaruan berikutnya!',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Oke, Mengerti'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  size: 26,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: darkPrimary.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded,
                      color: darkPrimary, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClockCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const ClockWidget(),
    );
  }

  Widget _buildSummaryGrid(
      BuildContext context, Map<String, int> summary, WidgetRef ref) {
    final cards = [
      _SummaryCard('Total Tasks', '${summary['total']}', Icons.task_alt_rounded,
          darkPrimary, 0),
      _SummaryCard('Upcoming', '${summary['upcoming']}', Icons.event_rounded,
          darkSecondary, 2),
      _SummaryCard('Overdue', '${summary['overdue']}', Icons.warning_rounded,
          statusOverdue, 4),
      _SummaryCard('Completed', '${summary['completed']}',
          Icons.check_circle_rounded, statusCompleted, 5),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children:
          cards.map((c) => _buildSummaryCardWidget(context, c, ref)).toList(),
    );
  }

  Widget _buildSummaryCardWidget(
      BuildContext context, _SummaryCard card, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        ref.read(taskTabIndexProvider.notifier).state = card.tabIndex;
        ref.read(navIndexProvider.notifier).state = 1;
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isDark
              ? null
              : Border.all(
                  color: card.color.withValues(alpha: 0.25),
                  width: 1.5,
                ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? card.color.withValues(alpha: 0.1)
                  : card.color.withValues(alpha: 0.15),
              blurRadius: isDark ? 12 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: isDark ? 0.15 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: card.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.value,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: card.color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Lengkap',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: card.color.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: card.color.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmBanner(
      BuildContext context, WidgetRef ref, List<TaskModel> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final nextTask = tasks.firstWhere(
      (t) => t.status == TaskStatus.todo,
      orElse: () => tasks.first,
    );

    return GestureDetector(
      onTap: () {
        ref.read(activeAlarmTaskIdProvider.notifier).state = nextTask.id;
        ref.read(alarmActiveProvider.notifier).state = true;
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AlarmScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _PulseIndicator(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 Next Alarm in 2h 15m',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"${nextTask.title}" • ${nextTask.timeLabel}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: _anim.value * 0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int tabIndex;
  const _SummaryCard(
      this.label, this.value, this.icon, this.color, this.tabIndex);
}
