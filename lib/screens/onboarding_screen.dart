// Photos sourced from Unsplash (unsplash.com) — free to use under the Unsplash License.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_providers.dart';

// ─── Data model ───────────────────────────────────────────────────────────────
class _PageData {
  final String imageUrl;
  final String? categoryLabel;
  final IconData? categoryIcon;
  final Color categoryColor;
  final String title;
  final String description;
  final List<String> bullets;
  final bool isLast;

  const _PageData({
    required this.imageUrl,
    this.categoryLabel,
    this.categoryIcon,
    this.categoryColor = const Color(0xFF7C3AED),
    required this.title,
    required this.description,
    this.bullets = const [],
    this.isLast = false,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _enterController;

  static const _pages = [
    // ── Page 1: Overview ──────────────────────────────────────────────────────
    _PageData(
      // Unsplash: productive workspace with notebook, pen, laptop
      imageUrl: 'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Overview',
      categoryIcon: Icons.auto_awesome_rounded,
      categoryColor: Color(0xFF7C3AED),
      title: 'Your Productivity\nSuperpower',
      description:
          'Plan tasks, set smart alarms, and track your progress — all '
          'in one app built to help you achieve more every single day.',
      bullets: [
        'Smart tasks with priorities & categories',
        'Custom music alarms for better mornings',
        'Analytics, streaks & progress insights',
      ],
    ),

    // ── Page 2: Task Management ───────────────────────────────────────────────
    _PageData(
      // Unsplash: open planner / agenda notebook
      imageUrl: 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Task Management',
      categoryIcon: Icons.checklist_rounded,
      categoryColor: Color(0xFF059669),
      title: 'Plan Tasks\nLike a Pro',
      description:
          'Create tasks with due dates, repeat patterns, and separate alarms. '
          'Organize by category and priority — exactly your way.',
      bullets: [
        '5 categories: Work, Personal, Health, Study…',
        'Start & due date each with their own alarm',
        'Daily, weekly, weekday & custom repeat modes',
      ],
    ),

    // ── Page 3: Smart Alarm & Music ───────────────────────────────────────────
    _PageData(
      // Unsplash: Sony WH-1000XM3 headphones
      imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Smart Alarm',
      categoryIcon: Icons.alarm_rounded,
      categoryColor: Color(0xFFEC4899),
      title: 'Wake Up\nthe Right Way',
      description:
          'Pick any track as your alarm tone. Customize snooze, volume, and '
          'alarm mode to perfectly match your morning routine.',
      bullets: [
        '3 modes: notification, vibrate & full alarm',
        'Music library with favorites & categories',
        'Multiple reminder intervals per task',
      ],
    ),

    // ── Page 4: Pomodoro Timer ────────────────────────────────────────────────
    _PageData(
      // Unsplash: person focused at desk / deep work
      imageUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Pomodoro Timer',
      categoryIcon: Icons.timer_rounded,
      categoryColor: Color(0xFFEF4444),
      title: 'Focus Deep,\nRest Well',
      description:
          'Use the Pomodoro technique to stay in the zone. Work in timed '
          'bursts, then recharge — so you can do more without burning out.',
      bullets: [
        'Custom work & break duration settings',
        'Session history with daily focus totals',
        'Start a session instantly from the home screen',
      ],
    ),

    // ── Page 5: Habit Tracker ─────────────────────────────────────────────────
    _PageData(
      // Unsplash: person running / building a routine
      imageUrl: 'https://images.unsplash.com/photo-1549060279-7e168fcee0c2'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Habit Tracker',
      categoryIcon: Icons.repeat_rounded,
      categoryColor: Color(0xFF0EA5E9),
      title: 'Build Habits\nThat Stick',
      description:
          'Define daily or weekly habits, track streaks, and visualise '
          'your consistency over time with a 30-day heatmap.',
      bullets: [
        'Daily, weekly & custom frequency goals',
        'Streak counter & 30-day completion heatmap',
        'Color-coded categories for a quick overview',
      ],
    ),

    // ── Page 6: Notes ─────────────────────────────────────────────────────────
    _PageData(
      // Unsplash: open notebook on desk
      imageUrl: 'https://images.unsplash.com/photo-1517842645767-c639042777db'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Notes',
      categoryIcon: Icons.sticky_note_2_rounded,
      categoryColor: Color(0xFF14B8A6),
      title: 'Capture Ideas\nAnywhere',
      description:
          'Jot down thoughts in organised folders and set smart reminders '
          'so important notes always surface at the right moment.',
      bullets: [
        'Folder-based organisation for any topic',
        'Reminders: one-time, interval or day-of-month',
        'Auto-save as you type — never lose a word',
      ],
    ),

    // ── Page 7: Statistics & Insights ────────────────────────────────────────
    _PageData(
      // Unsplash: analytics / data charts
      imageUrl: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71'
          '?auto=format&fit=crop&w=800&q=80',
      categoryLabel: 'Insights',
      categoryIcon: Icons.insights_rounded,
      categoryColor: Color(0xFFF59E0B),
      title: 'Measure What\nMatters',
      description:
          'Understand your productivity with beautiful charts. Track completion '
          'rates, habit consistency, and hit personal records.',
      bullets: [
        'Weekly, monthly & yearly performance reports',
        'Completion rate trends & category breakdowns',
        'Streaks, personal bests & activity heatmap',
      ],
    ),

    // ── Page 8: Get Started (special layout) ─────────────────────────────────
    _PageData(
      // Unsplash: golden sunrise / new beginning
      imageUrl: 'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8'
          '?auto=format&fit=crop&w=800&q=80',
      title: 'Ready to\nTake Control?',
      description: 'Your goals, your schedule, your rules.\n'
          'Let SmartAlarm help you start every day\nwith clarity and purpose.',
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _enterController.forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _enterController.reset();
    _enterController.forward();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    } else {
      _done();
    }
  }

  Future<void> _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      ref.read(onboardingDoneProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Onboarding always has a dark background — force white system bar icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0221),
        body: Stack(
          children: [
            // Page content
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) =>
                  _buildPageContent(_pages[index], context),
            ),

            // Skip button (only on non-last pages)
            if (!page.isLast)
              Positioned(
                top: topPad + 12,
                right: 20,
                child: TextButton(
                  onPressed: _done,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.65),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // Bottom controls (dots + button)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(bottomPad, page),
            ),
          ],
        ), // Stack
      ), // Scaffold
    ); // AnnotatedRegion
  }

  Widget _buildPageContent(_PageData page, BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final imageH = screenH * 0.50;
    final bottomCtrlH = 118.0 + MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Image section ──────────────────────────────────────────────────
        SizedBox(
          height: imageH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                page.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(color: const Color(0xFF1A0E3F)),
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        page.categoryColor.withValues(alpha: 0.3),
                        const Color(0xFF0D0221),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      page.categoryIcon ?? Icons.star_rounded,
                      size: 80,
                      color: page.categoryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              // Top dark fade (status bar readability)
              Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D0221).withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Bottom dark fade (content blend)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: imageH * 0.48,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0xFF0D0221),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Content section ────────────────────────────────────────────────
        Expanded(
          child: page.isLast
              ? _buildLastPageContent(page)
              : _buildRegularContent(page),
        ),

        // Spacer so content doesn't hide behind bottom controls
        SizedBox(height: bottomCtrlH),
      ],
    );
  }

  // ── Regular page (category chip + title + description + bullets) ──────────
  Widget _buildRegularContent(_PageData page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip
          _animated(
            delay: 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: page.categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: page.categoryColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(page.categoryIcon, size: 14, color: page.categoryColor),
                  const SizedBox(width: 6),
                  Text(
                    page.categoryLabel!,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: page.categoryColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          _animated(
            delay: 0.08,
            child: Text(
              page.title,
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Description
          _animated(
            delay: 0.18,
            child: Text(
              page.description,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Bullets
          ...List.generate(page.bullets.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _animated(
                delay: 0.28 + i * 0.10,
                child: _buildBullet(page.bullets[i], page.categoryColor),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Last page (centered, no bullets) ─────────────────────────────────────
  Widget _buildLastPageContent(_PageData page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative sparkle row
          _animated(
            delay: 0.0,
            child: Row(
              children: [
                _sparkle(const Color(0xFF7C3AED), 8),
                const SizedBox(width: 6),
                _sparkle(const Color(0xFFEC4899), 6),
                const SizedBox(width: 6),
                _sparkle(const Color(0xFFF59E0B), 10),
              ],
            ),
          ),
          const Spacer(flex: 1),

          // Title
          _animated(
            delay: 0.06,
            child: Text(
              page.title,
              style: GoogleFonts.nunito(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
              ),
            ),
          ),
          const Spacer(flex: 1),

          // Description
          _animated(
            delay: 0.16,
            child: Text(
              page.description,
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.70),
                height: 1.65,
              ),
            ),
          ),
          const Spacer(flex: 2),

          // Feature recap chips
          _animated(
            delay: 0.26,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _featureChip(
                    Icons.task_alt_rounded, 'Tasks', const Color(0xFF059669)),
                _featureChip(
                    Icons.alarm_rounded, 'Alarms', const Color(0xFFEC4899)),
                _featureChip(
                    Icons.music_note_rounded, 'Music', const Color(0xFF7C3AED)),
                _featureChip(
                    Icons.timer_rounded, 'Pomodoro', const Color(0xFFEF4444)),
                _featureChip(
                    Icons.repeat_rounded, 'Habits', const Color(0xFF0EA5E9)),
                _featureChip(Icons.sticky_note_2_rounded, 'Notes',
                    const Color(0xFF14B8A6)),
                _featureChip(
                    Icons.bar_chart_rounded, 'Stats', const Color(0xFFF59E0B)),
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sparkle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: size,
          ),
        ],
      ),
    );
  }

  // ── Bullet item ──────────────────────────────────────────────────────────
  Widget _buildBullet(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 14, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  // ── Entrance animation wrapper ────────────────────────────────────────────
  Widget _animated({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _enterController,
      builder: (context, _) {
        final end = (delay + 0.42).clamp(0.0, 1.0);
        final t = CurvedAnimation(
          parent: _enterController,
          curve: Interval(delay, end, curve: Curves.easeOut),
        );
        final opacity =
            Tween<double>(begin: 0, end: 1).evaluate(t).clamp(0.0, 1.0);
        final slide = Tween<double>(begin: 18, end: 0).evaluate(t);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, slide), child: child),
        );
      },
    );
  }

  // ── Bottom controls ───────────────────────────────────────────────────────
  Widget _buildBottomControls(double bottomPad, _PageData page) {
    final isLast = page.isLast;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 20 + bottomPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D0221).withValues(alpha: 0.0),
            const Color(0xFF0D0221).withValues(alpha: 0.97),
            const Color(0xFF0D0221),
          ],
          stops: const [0.0, 0.22, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final active = _currentPage == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? _pages[_currentPage].isLast
                          ? const Color(0xFF7C3AED)
                          : _pages[_currentPage].categoryColor
                      : Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Action button
          if (isLast)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.rocket_launch_rounded,
                          size: 20, color: Colors.white),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pages[_currentPage]
                      .categoryColor
                      .withValues(alpha: 0.18),
                  foregroundColor: _pages[_currentPage].categoryColor,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _pages[_currentPage]
                          .categoryColor
                          .withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
