import 'dart:async';
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

  // Restore persisted auth state
  final authState = await StorageService.loadAuthState();
  final savedIsLoggedIn = authState['isLoggedIn'] as bool;
  final savedUserName = authState['userName'] as String;
  final savedUserEmail = authState['userEmail'] as String;
  final savedHasUnsynced = await StorageService.loadHasUnsynced();

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
        isLoggedInProvider.overrideWith((_) => savedIsLoggedIn),
        currentUserNameProvider.overrideWith((_) => savedUserName),
        currentUserEmailProvider.overrideWith((_) => savedUserEmail),
        hasUnsyncedLocalTasksProvider.overrideWith((_) => savedHasUnsynced),
        birthdayBadgePermanentlyDismissedProvider
            .overrideWith((_) => savedBirthdayBadgeDismissed),
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

    return MaterialApp(
      title: 'Alarm Scheduler',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      theme: AppTheme.buildWithAccent(Brightness.light, accent),
      darkTheme: AppTheme.buildWithAccent(Brightness.dark, accent),
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

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeScreen(),
    TaskListScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Widget navItem(
        IconData icon, IconData activeIcon, String label, int index) {
      final active = navIndex == index;
      final color = active ? primary : onSurface.withValues(alpha: 0.5);
      return Expanded(
        child: InkWell(
          onTap: () => ref.read(navIndexProvider.notifier).state = index,
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
        body: IndexedStack(
          index: navIndex,
          children: _screens,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
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
                color: primary.withValues(alpha: 0.45),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 34),
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          elevation: 8,
          child: SizedBox(
            height: 62,
            child: Row(
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
    );
  }
}
