import 'dart:async';
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
import 'pomodoro_screen.dart';
import 'notification_list_screen.dart';
import 'habit_screen.dart';
import 'notes_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tasks = ref.read(taskListProvider);
      ref.read(notificationListProvider.notifier).syncTriggeredTasks(tasks);
    });
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
        final tasks = ref.read(taskListProvider);
        ref.read(notificationListProvider.notifier).syncTriggeredTasks(tasks);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        const SizedBox(height: 16),
                        // Quick Access Card (Habit + Pomodoro + Notes)
                        _buildQuickAccessCard(context, isDark),
                        // Summary Grid
                        _buildSummaryGrid(context, summary, ref),
                        // Alarm Banner
                        _buildAlarmBanner(context, ref, tasks),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationListScreen()),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F0FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: darkPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Builder(builder: (context) {
                      final unread = ref.watch(unreadNotificationCountProvider);
                      if (unread == 0) return const SizedBox.shrink();
                      return Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 8),
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

  Widget _buildQuickAccessCard(BuildContext context, bool isDark) {
    final habits = ref.watch(todayHabitsProvider);
    final today = DateTime.now();
    final completed = habits.where((h) => h.isCompletedOn(today)).length;
    final total = habits.length;
    final pct = total > 0 ? completed / total : 0.0;

    final pomodoroState = ref.watch(pomodoroProvider);

    final notesState = ref.watch(noteProvider);
    final totalFolders = notesState.folders.length;
    final totalFiles = notesState.files.length;
    final overdueCount =
        notesState.folders.where((f) => f.isReminderOverdue).length +
            notesState.files.where((f) => f.isReminderOverdue).length;

    final primary = Theme.of(context).colorScheme.primary;
    final surface = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primary.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header label
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'QUICK ACCESS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withValues(alpha: 0.38),
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (pomodoroState.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pomodoroState.formattedTime,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 3 tab-style buttons
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Habit Tracker
                Expanded(
                  child: _QuickAccessButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HabitScreen()),
                    ),
                    icon: Icons.track_changes_rounded,
                    iconColor: primary,
                    iconBg: primary.withValues(alpha: 0.12),
                    label: 'Habits',
                    sublabel:
                        total == 0 ? 'No habits' : '$completed/$total done',
                    isDark: isDark,
                    onSurface: onSurface,
                    bottomWidget: total > 0
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor:
                                    primary.withValues(alpha: 0.10),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  pct >= 1.0 ? Colors.green : primary,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: onSurface.withValues(alpha: 0.08),
                ),
                // Pomodoro
                Expanded(
                  child: _QuickAccessButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PomodoroScreen()),
                    ),
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFFFF6B6B),
                    iconBg: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                    label: 'Pomodoro',
                    sublabel: pomodoroState.isActive
                        ? pomodoroState.stateLabel
                        : 'Stay focused',
                    isDark: isDark,
                    onSurface: onSurface,
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: onSurface.withValues(alpha: 0.08),
                ),
                // My Notes
                Expanded(
                  child: _QuickAccessButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotesScreen()),
                    ),
                    icon: Icons.auto_stories_rounded,
                    iconColor: const Color(0xFF26C6DA),
                    iconBg: const Color(0xFF26C6DA).withValues(alpha: 0.12),
                    label: 'My Notes',
                    sublabel: totalFolders == 0 && totalFiles == 0
                        ? 'Empty'
                        : '$totalFolders folder · $totalFiles note',
                    badge: overdueCount > 0 ? '$overdueCount' : null,
                    badgeColor: Colors.red,
                    isDark: isDark,
                    onSurface: onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final childAspectRatio =
        (1.4 / (textScale > 1.0 ? textScale * 1.15 : 1.0)).clamp(0.8, 1.4);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        card.value,
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: card.color,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Lihat Lengkap',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: card.color.withValues(alpha: 0.8),
                            ),
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
    final now = DateTime.now();

    final alarmTasks = tasks.where((t) {
      if (t.status == TaskStatus.completed) return false;
      if (t.alarmMode != AlarmMode.alarmMusic) return false;
      final alarmDt = DateTime(
          t.date.year, t.date.month, t.date.day, t.time.hour, t.time.minute);
      return alarmDt.isAfter(now);
    }).toList();

    if (alarmTasks.isEmpty) return const SizedBox(height: 20);

    alarmTasks.sort((a, b) {
      final aDt = DateTime(
          a.date.year, a.date.month, a.date.day, a.time.hour, a.time.minute);
      final bDt = DateTime(
          b.date.year, b.date.month, b.date.day, b.time.hour, b.time.minute);
      return aDt.compareTo(bDt);
    });

    final nextTask = alarmTasks.first;
    final alarmDt = DateTime(nextTask.date.year, nextTask.date.month,
        nextTask.date.day, nextTask.time.hour, nextTask.time.minute);
    final diff = alarmDt.difference(now);

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final countdownLabel = hours > 0
        ? 'Next Alarm in ${hours}h ${minutes}m'
        : 'Next Alarm in ${minutes}m';

    return Column(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            ref.read(activeAlarmTaskIdProvider.notifier).state = nextTask.id;
            ref.read(alarmActiveProvider.notifier).state = true;
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AlarmScreen()));
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
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
                        '🔔 $countdownLabel',
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
        ),
        const SizedBox(height: 24),
      ],
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

class _QuickAccessButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String sublabel;
  final String? badge;
  final Color? badgeColor;
  final Widget? bottomWidget;
  final bool isDark;
  final Color onSurface;

  const _QuickAccessButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.sublabel,
    required this.isDark,
    required this.onSurface,
    this.badge,
    this.badgeColor,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.06 : 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor ?? Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 2),
            // Sub label
            Text(
              sublabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            // Optional bottom widget (e.g. progress bar)
            if (bottomWidget != null) bottomWidget!,
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buka',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: iconColor.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 8,
                  color: iconColor.withValues(alpha: 0.65),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
