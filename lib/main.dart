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

  // Init notification service
  await NotificationService.init();
  await NotificationService.requestPermissions();

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
        isLoggedInProvider.overrideWith((_) => savedIsLoggedIn),
        currentUserNameProvider.overrideWith((_) => savedUserName),
        currentUserEmailProvider.overrideWith((_) => savedUserEmail),
        hasUnsyncedLocalTasksProvider.overrideWith((_) => savedHasUnsynced),
      ],
      child: const SmartAlarmApp(),
    ),
  );
}

class SmartAlarmApp extends ConsumerWidget {
  const SmartAlarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Smart Alarm & Task Scheduler',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
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
    NotificationService.onTap = (taskId) {
      final tasks = ref.read(taskListProvider);
      final matched = tasks.where((t) => t.id == taskId).toList();
      if (matched.isNotEmpty && !ref.read(alarmActiveProvider)) {
        ref.read(activeAlarmTaskIdProvider.notifier).state = taskId;
        ref.read(alarmActiveProvider.notifier).state = true;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AlarmScreen(),
          ),
        );
      }
    };
    // Check if app was launched via a notification
    NotificationService.checkLaunchPayload();

    // Foreground alarm checker — fires every 30 s.
    // When the scheduled time arrives while the app is in the foreground,
    // flutter_local_notifications won't open AlarmScreen automatically,
    // so we check manually and push the screen.
    // Also checks for tasks that have become overdue.
    _alarmChecker = Timer.periodic(const Duration(seconds: 30), (_) {
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

      final alarmDt = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.time.hour,
        task.time.minute,
      );

      // Key to avoid re-triggering the same alarm minute
      final key = '${task.id}_${alarmDt.millisecondsSinceEpoch}';
      if (_firedForeground.contains(key)) continue;

      final diff = now.difference(alarmDt).inSeconds;
      // Trigger if task alarm fired within the last 90 seconds
      if (diff >= 0 && diff <= 90) {
        _firedForeground.add(key);
        ref.read(taskListProvider.notifier).markInProgress(task.id);
        ref.read(activeAlarmTaskIdProvider.notifier).state = task.id;
        ref.read(alarmActiveProvider.notifier).state = true;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const AlarmScreen(),
          ),
        );
        break; // show one at a time
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: IndexedStack(
          index: navIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navIndex,
          onDestinationSelected: (i) =>
              ref.read(navIndexProvider.notifier).state = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
