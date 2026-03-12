import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/alarm_screen.dart';
import 'screens/add_task_screen.dart';
import 'screens/pomodoro_screen.dart';
import 'screens/habit_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/note_file_editor_screen.dart';
import 'models/task_model.dart';

/// Global [NavigatorKey] used by [NotificationService] to push AlarmScreen
/// from notification taps (works even when app is backgrounded).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Restore persisted onboarding state
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // Restore persisted settings
  final savedTheme = await StorageService.loadThemeMode();
  final savedMusic = await StorageService.loadDefaultMusic();
  final savedVolume = await StorageService.loadDefaultVolume();
  final savedSnooze = await StorageService.loadDefaultSnooze();
  final savedVib = await StorageService.loadVibration();
  final savedDnd = await StorageService.loadDnd();
  final savedAccent = await StorageService.loadAccentIndex();
  final savedRemind = await StorageService.loadDefaultReminder();
  final savedNotifMusic = await StorageService.loadDefaultNotifMusic();
  final savedNotifVolume = await StorageService.loadDefaultNotifVolume();
  final savedBirthdayBadgeDismissed =
      await StorageService.loadBirthdayBadgeDismissed();
  final savedFontScaleIndex = await StorageService.loadFontScaleIndex();

  // Apply settings to NotificationService static fields
  NotificationService.vibrationEnabled = savedVib;
  NotificationService.dndEnabled = savedDnd;
  NotificationService.defaultAlarmMusic = savedMusic;
  NotificationService.defaultAlarmVolume = savedVolume / 100.0;
  NotificationService.defaultNotifMusic = savedNotifMusic;
  NotificationService.defaultNotifVolume = savedNotifVolume / 100.0;
  NotificationService.defaultReminder = savedRemind;

  // Init notification service (channels only — permissions requested after runApp)
  await NotificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        onboardingDoneProvider.overrideWith((_) => onboardingDone),
        themeModeProvider.overrideWith((_) => savedTheme),
        defaultMusicProvider.overrideWith((_) => savedMusic),
        defaultVolumeProvider.overrideWith((_) => savedVolume),
        defaultSnoozeProvider.overrideWith((_) => savedSnooze),
        vibrationEnabledProvider.overrideWith((_) => savedVib),
        dndEnabledProvider.overrideWith((_) => savedDnd),
        accentColorIndexProvider.overrideWith((_) => savedAccent),
        defaultReminderProvider.overrideWith((_) => savedRemind),
        defaultNotifMusicProvider.overrideWith((_) => savedNotifMusic),
        defaultNotifVolumeProvider.overrideWith((_) => savedNotifVolume),
        birthdayBadgePermanentlyDismissedProvider
            .overrideWith((_) => savedBirthdayBadgeDismissed),
        fontScaleIndexProvider.overrideWith((_) => savedFontScaleIndex),
      ],
      child: const SmartAlarmApp(),
    ),
  );
}

class SmartAlarmApp extends ConsumerWidget {
  const SmartAlarmApp({super.key});

  static const _accentColors = [
    Color(0xFF7B6EF6), // purple (default)
    Color(0xFF4ECDC4), // teal
    Color(0xFFFF6B9D), // pink
    Color(0xFF4A90E2), // blue
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentIndex = ref.watch(accentColorIndexProvider);
    final accent =
        _accentColors[accentIndex.clamp(0, _accentColors.length - 1)];
    final fontScaleIndex = ref.watch(fontScaleIndexProvider);
    const fontScales = [0.85, 1.0, 1.15, 1.3];
    final fontScale =
        fontScales[fontScaleIndex.clamp(0, fontScales.length - 1)];

    return MaterialApp(
      title: 'Alarm Scheduler',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      theme: AppTheme.buildWithAccent(Brightness.light, accent),
      darkTheme: AppTheme.buildWithAccent(Brightness.dark, accent),
      // Override system font scale so Android "large text" setting doesn't
      // affect this app. Font size is controlled only by fontScaleIndexProvider.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();

  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> {
  Timer? _alarmChecker;
  // Tracks (taskId + alarmMinute) pairs already triggered in foreground
  final _firedForeground = <String>{};

  @override
  void initState() {
    super.initState();
    // Wire notification tap → open AlarmScreen (with task active) so music
    // starts playing immediately when the user taps the alarm notification or
    // when the full-screen intent auto-launches the app.
    NotificationService.onTap = (taskId) async {
      // Jika notifikasi dari Pomodoro → arahkan ke PomodoroScreen
      if (taskId == 'pomodoro') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const PomodoroScreen()),
        );
        return;
      }

      // Notifikasi dari Notes folder
      if (taskId.startsWith('note_folder_')) {
        final folderId = taskId.substring('note_folder_'.length);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => NotesScreen(openFolderId: folderId),
          ),
        );
        return;
      }

      // Notifikasi dari Notes file
      if (taskId.startsWith('note_file_')) {
        final fileId = taskId.substring('note_file_'.length);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => NoteFileEditorScreen(fileId: fileId),
          ),
        );
        return;
      }

      final tasks = ref.read(taskListProvider);
      final matched = tasks.where((t) => t.id == taskId).toList();
      if (matched.isNotEmpty && !ref.read(alarmActiveProvider)) {
        final task = matched.first;
        // Hanya buka AlarmScreen untuk task dengan alarmMusic
        if (task.alarmMode == AlarmMode.alarmMusic) {
          // Cancel the notification first so its sound stops before AlarmScreen
          // starts playing the in-app audio (prevents double sound).
          await NotificationService.cancelAlarmOnly(taskId);
          ref.read(activeAlarmTaskIdProvider.notifier).state = taskId;
          ref.read(alarmActiveProvider.notifier).state = true;
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const AlarmScreen(),
            ),
          );
        }
      }
    };
    // Check if app was launched via a notification
    NotificationService.checkLaunchPayload();

    // Request notification permissions after UI is rendered
    // (prevents blank white screen during permission dialogs)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      NotificationService.requestPermissions();
    });

    // Foreground alarm checker — fires every 5 s.
    // When the scheduled time arrives while the app is in the foreground,
    // flutter_local_notifications won't open AlarmScreen automatically,
    // so we check manually and push the screen.
    // Also checks for tasks that have become overdue.
    _alarmChecker = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForegroundAlarms();
      ref.read(taskListProvider.notifier).checkAndUpdateOverdue();
    });
  }

  void _checkForegroundAlarms() {
    if (!mounted) return;
    if (ref.read(alarmActiveProvider)) return; // alarm already showing

    final tasks = ref.read(taskListProvider);
    final now = DateTime.now();

    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      // Hanya buka AlarmScreen untuk task dengan alarmMusic,
      // karena notificationOnly cukup via notifikasi sistem.
      if (task.alarmMode != AlarmMode.alarmMusic) continue;

      final taskDt = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.time.hour,
        task.time.minute,
      );

      // ── 1. Main alarm (start time) ─────────────────────────────────────
      final mainKey = '${task.id}_${taskDt.millisecondsSinceEpoch}';
      if (!_firedForeground.contains(mainKey)) {
        final diff = now.difference(taskDt).inSeconds;
        if (diff >= 0 && diff <= 90) {
          _firedForeground.add(mainKey);
          ref.read(taskListProvider.notifier).markInProgress(task.id);
          NotificationService.cancelAlarmOnly(task.id);
          ref.read(activeAlarmTaskIdProvider.notifier).state = task.id;
          ref.read(alarmActiveProvider.notifier).state = true;
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const AlarmScreen(),
            ),
          );
          return; // show one at a time
        }
      }

      // ── 2. Start-time reminders ────────────────────────────────────────
      final startReminders = task.reminders.isNotEmpty
          ? task.reminders
          : [NotificationService.defaultReminder];
      bool fired = false;
      for (int i = 0; i < startReminders.length; i++) {
        final mins = NotificationService.reminderMinutes(startReminders[i]);
        if (mins == null) continue;
        final reminderDt = taskDt.subtract(Duration(minutes: mins));
        if (reminderDt.isBefore(DateTime(2000))) continue;
        final reminderKey =
            '${task.id}_r${i}_${reminderDt.millisecondsSinceEpoch}';
        if (_firedForeground.contains(reminderKey)) continue;
        final diff = now.difference(reminderDt).inSeconds;
        if (diff >= 0 && diff <= 90) {
          _firedForeground.add(reminderKey);
          ref.read(activeAlarmTaskIdProvider.notifier).state = task.id;
          ref.read(alarmActiveProvider.notifier).state = true;
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const AlarmScreen(),
            ),
          );
          fired = true;
          break;
        }
      }
      if (fired) return;

      // ── 3. Due-date reminders ─────────────────────────────────────────
      if (task.dueDateEnabled &&
          task.dueDate != null &&
          task.dueReminderEnabled &&
          task.dueReminders.isNotEmpty) {
        final dTime = task.dueTime;
        final dueDt = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
          dTime?.hour ?? 23,
          dTime?.minute ?? 59,
        );
        for (int i = 0; i < task.dueReminders.length; i++) {
          final mins =
              NotificationService.reminderMinutes(task.dueReminders[i]);
          if (mins == null) continue;
          final reminderDt = dueDt.subtract(Duration(minutes: mins));
          final reminderKey =
              '${task.id}_dr${i}_${reminderDt.millisecondsSinceEpoch}';
          if (_firedForeground.contains(reminderKey)) continue;
          final diff = now.difference(reminderDt).inSeconds;
          if (diff >= 0 && diff <= 90) {
            _firedForeground.add(reminderKey);
            ref.read(activeAlarmTaskIdProvider.notifier).state = task.id;
            ref.read(alarmActiveProvider.notifier).state = true;
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const AlarmScreen(),
              ),
            );
            return;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _alarmChecker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final splashDone = ref.watch(splashDoneProvider);
    if (!splashDone) return const SplashScreen();

    final onboardingDone = ref.watch(onboardingDoneProvider);
    if (!onboardingDone) return const OnboardingScreen();

    return const MainShell();
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  static const _screens = [
    HomeScreen(),
    TaskListScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  bool _menuOpen = false;
  late AnimationController _menuCtrl;

  // Staggered animations for 4 menu items (index 0 = Task, nearest to FAB)
  late List<Animation<double>> _itemAnims;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _itemAnims = List.generate(4, (i) {
      // Each item starts animating slightly after the previous
      final start = i * 0.08;
      final end = (start + 0.70).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _menuCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });
  }

  @override
  void dispose() {
    _menuCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    if (_menuOpen) {
      _menuCtrl.forward();
    } else {
      _menuCtrl.reverse();
    }
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
    _menuCtrl.reverse();
  }

  void _openTaskForm(BuildContext context) {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }

  void _openHabits(BuildContext context) {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HabitScreen()),
    );
  }

  void _openPomodoro(BuildContext context) {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PomodoroScreen()),
    );
  }

  void _openNotes(BuildContext context) {
    _closeMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(navIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Speed dial items defined here so overlay in body can access them
    final items = [
      _SpeedDialItem(
        label: 'Task',
        icon: Icons.task_alt_rounded,
        color: primary,
        onTap: () => _openTaskForm(context),
        anim: _itemAnims[0],
      ),
      _SpeedDialItem(
        label: 'Habits',
        icon: Icons.loop_rounded,
        color: const Color(0xFF7B6EF6),
        onTap: () => _openHabits(context),
        anim: _itemAnims[1],
      ),
      _SpeedDialItem(
        label: 'Pomodoro',
        icon: Icons.timer_rounded,
        color: const Color(0xFFFF6B6B),
        onTap: () => _openPomodoro(context),
        anim: _itemAnims[2],
      ),
      _SpeedDialItem(
        label: 'Notes',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF26C6DA),
        onTap: () => _openNotes(context),
        anim: _itemAnims[3],
      ),
    ];

    Widget navItem(
        IconData icon, IconData activeIcon, String label, int index) {
      final active = navIndex == index;
      final color = active ? primary : onSurface.withValues(alpha: 0.5);
      return SizedBox(
        width: 72,
        child: InkWell(
          onTap: () {
            _closeMenu();
            ref.read(navIndexProvider.notifier).state = index;
          },
          splashColor: primary.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  active ? activeIcon : icon,
                  key: ValueKey(active),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        extendBody: true, // content extends behind BottomAppBar for FAB notch
        body: Stack(
          children: [
            IndexedStack(
              index: navIndex,
              children: _screens,
            ),
            // Dimming overlay when menu is open
            AnimatedOpacity(
              opacity: _menuOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: GestureDetector(
                  onTap: _closeMenu,
                  child: Container(color: Colors.black54),
                ),
              ),
            ),
            // Speed dial menu items overlay — circular arc around FAB
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: _buildArcMenu(context, items),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _buildFabCircle(context, primary),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: 0.06), // Sangat transparan
                blurRadius: 16, // Cukup lebar agar gradasinya lembut
                spreadRadius: -2, // Minus membuat shadow menyusut/lebih tipis
                offset: const Offset(0, -3), // Jaraknya didekatkan
              ),
            ],
          ),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            padding: EdgeInsets.zero,
            elevation: 0,
            child: SizedBox(
              height: 62,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  navItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
                  navItem(Icons.event_note_outlined, Icons.event_note_rounded,
                      'Schedule', 1),
                  const SizedBox(width: 80),
                  navItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded,
                      'Stats', 2),
                  navItem(Icons.settings_outlined, Icons.settings_rounded,
                      'Settings', 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabCircle(BuildContext context, Color primary) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            primary.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.55),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: _toggleMenu,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: anim,
              child: child,
            ),
            child: Icon(
              _menuOpen ? Icons.close_rounded : Icons.add_rounded,
              key: ValueKey(_menuOpen),
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArcMenu(BuildContext context, List<_SpeedDialItem> items) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const navHeight = 62.0;
    const radius = 110.0;
    // 4 items in a 120° arc centered on "straight up" from FAB
    const angleDegrees = [-55.0, -17.0, 17.0, 55.0];

    // FAB center: horizontally centered, at the top edge of BottomAppBar
    final fabCenterX = size.width / 2;
    final fabCenterY = size.height - bottomPadding - navHeight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final angleRad = angleDegrees[i] * math.pi / 180;
        final dx = radius * math.sin(angleRad);
        final dy = -radius * math.cos(angleRad); // negative = upward in screen

        return Positioned(
          left: fabCenterX + dx - 24,
          // offset -24 for icon center + -26 for label+gap above icon
          top: fabCenterY + dy - 50,
          child: AnimatedBuilder(
            animation: item.anim,
            builder: (ctx, child) {
              final v = item.anim.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label above icon
                Material(
                  color: isDark ? const Color(0xFF2A2A3A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: item.onTap,
                      child: Icon(item.icon, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SpeedDialItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Animation<double> anim;

  const _SpeedDialItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.anim,
  });
}
