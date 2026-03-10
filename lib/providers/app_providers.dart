import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dummy_data.dart';
import '../data/global_events.dart';
import '../models/task_model.dart';
import '../models/music_model.dart';
import '../models/birthday_model.dart';
import '../models/pomodoro_model.dart';
import '../services/holiday_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

// ─── Theme Provider ───────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ─── Navigation Index ─────────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─── Onboarding ───────────────────────────────────────────────────────────────
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

// ─── Splash ───────────────────────────────────────────────────────────────────
final splashDoneProvider = StateProvider<bool>((ref) => false);

// ─── Task Providers ───────────────────────────────────────────────────────────
class TaskNotifier extends StateNotifier<List<TaskModel>> {
  TaskNotifier() : super([]) {
    _loadFromStorage();
  }

  // ── Load persisted tasks ───────────────────────────────────────────────────
  Future<void> _loadFromStorage() async {
    final saved = await StorageService.loadTasks();
    state = saved;
    await checkAndUpdateOverdue();
  }

  Future<void> _save() async {
    await StorageService.saveTasks(state);
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────
  Future<void> addTask(TaskModel task) async {
    state = [...state, task];
    await _save();
    await _scheduleAll(task);
  }

  Future<void> updateTask(TaskModel task) async {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];
    await _save();
    await NotificationService.cancelTaskAlarm(task.id);
    await _scheduleAll(task);
  }

  Future<void> deleteTask(String id) async {
    await NotificationService.cancelTaskAlarm(id);
    state = state.where((t) => t.id != id).toList();
    await _save();
  }

  Future<void> markComplete(String id) async {
    await NotificationService.cancelTaskAlarm(id);
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(
            status: TaskStatus.completed,
            history: [...t.history, 'Completed on ${_todayLabel()}'],
          )
        else
          t,
    ];
    await _save();
  }

  Future<void> markInProgress(String id) async {
    final updated = <TaskModel>[];
    bool changed = false;
    for (final t in state) {
      if (t.id == id && t.status == TaskStatus.todo) {
        changed = true;
        updated.add(t.copyWith(
          status: TaskStatus.inProgress,
          history: [...t.history, 'Started on ${_todayLabel()}'],
        ));
      } else {
        updated.add(t);
      }
    }
    if (changed) {
      state = updated;
      await _save();
    }
  }

  /// Marks tasks as overdue when their effective due date has passed.
  /// Also transitions upcoming → todo when the task's start date arrives.
  ///
  /// For tasks with [dueDateEnabled] = true: uses [dueDate] (+ [dueTime] if set).
  /// For tasks WITHOUT a due date: effective due date = end of [task.date].
  /// i.e. a task created/scheduled on day X with no due date becomes overdue
  /// the moment midnight of day X passes (next day starts).
  Future<void> checkAndUpdateOverdue() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updated = <TaskModel>[];
    bool changed = false;

    for (final task in state) {
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.overdue) {
        updated.add(task);
        continue;
      }

      // Repeating tasks are never marked overdue — they recur on future dates.
      if (task.repeat != RepeatType.none) {
        updated.add(task);
        continue;
      }

      // Compute effective due date
      final DateTime effectiveDue;
      if (task.dueDateEnabled && task.dueDate != null) {
        if (task.dueTime != null) {
          effectiveDue = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            task.dueTime!.hour,
            task.dueTime!.minute,
          );
        } else {
          effectiveDue = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
            23,
            59,
            59,
          );
        }
      } else {
        // No due date → deadline is end of the task's start date
        effectiveDue = DateTime(
          task.date.year,
          task.date.month,
          task.date.day,
          23,
          59,
          59,
        );
      }

      if (now.isAfter(effectiveDue)) {
        // Transition to overdue regardless of current status
        changed = true;
        updated.add(task.copyWith(
          status: TaskStatus.overdue,
          history: [...task.history, 'Overdue since ${_todayLabel()}'],
        ));
      } else if (task.status == TaskStatus.upcoming) {
        // Transition upcoming → todo when the task's start date has arrived
        final taskDay =
            DateTime(task.date.year, task.date.month, task.date.day);
        if (!taskDay.isAfter(today)) {
          changed = true;
          updated.add(task.copyWith(status: TaskStatus.todo));
        } else {
          updated.add(task);
        }
      } else {
        updated.add(task);
      }
    }

    if (changed) {
      state = updated;
      await _save();
    }
  }

  Future<void> clearAll() async {
    await NotificationService.cancelAll();
    state = [];
    await _save();
  }

  /// Import [tasks] into the task list.
  ///
  /// When [replace] is true, all existing tasks are cleared first.
  /// When [replace] is false, imported tasks are merged (skipping IDs that
  /// already exist).
  Future<int> importTasksBulk(List<TaskModel> tasks,
      {required bool replace}) async {
    int count;
    if (replace) {
      await NotificationService.cancelAll();
      state = List.of(tasks);
      count = tasks.length;
    } else {
      final existingIds = state.map((t) => t.id).toSet();
      final newTasks = tasks.where((t) => !existingIds.contains(t.id)).toList();
      state = [...state, ...newTasks];
      count = newTasks.length;
    }
    await _save();
    for (final task in tasks) {
      if (task.status != TaskStatus.completed) {
        await _scheduleAll(task);
      }
    }
    return count;
  }

  // ── Schedule notifications + reminders ─────────────────────────────────────
  Future<void> _scheduleAll(TaskModel task) async {
    if (task.status == TaskStatus.completed) return;
    await NotificationService.scheduleTaskAlarm(task);
    await NotificationService.scheduleReminders(task);
    await NotificationService.scheduleDueReminders(task);
    // Schedule subtask reminders
    await NotificationService.scheduleSubTaskReminders(task);
    // Note: Checklist items don't support reminders
  }

  // ── Reschedule all after boot / reopen ─────────────────────────────────────
  Future<void> rescheduleAll() async {
    for (final task in state) {
      if (task.status != TaskStatus.completed) {
        await _scheduleAll(task);
      }
    }
  }

  String _todayLabel() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
      'Dec',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

final taskListProvider = StateNotifierProvider<TaskNotifier, List<TaskModel>>(
    (ref) => TaskNotifier());

// ─── Task Filter / Search ─────────────────────────────────────────────────────
final taskSearchQueryProvider = StateProvider<String>((ref) => '');

// 0=All,1=InProgress,2=Upcoming,3=Risk,4=Overdue,5=Done,6=Birthday
final taskTabIndexProvider = StateProvider<int>((ref) => 0);

final taskPriorityFilterProvider = StateProvider<TaskPriority?>((ref) => null);

// true = ascending (oldest first), false = descending (newest first)
final taskSortAscendingProvider = StateProvider<bool>((ref) => true);

final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final query = ref.watch(taskSearchQueryProvider).toLowerCase();
  final tabIndex = ref.watch(taskTabIndexProvider);
  final priority = ref.watch(taskPriorityFilterProvider);
  final sortAsc = ref.watch(taskSortAscendingProvider);

  var filtered = tasks;

  if (query.isNotEmpty) {
    filtered = filtered
        .where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query))
        .toList();
  }

  switch (tabIndex) {
    case 1:
      filtered =
          filtered.where((t) => t.status == TaskStatus.inProgress).toList();
      break;
    case 2:
      filtered =
          filtered.where((t) => t.status == TaskStatus.upcoming).toList();
      break;
    case 3:
      filtered = filtered.where((t) => t.status == TaskStatus.risk).toList();
      break;
    case 4:
      filtered = filtered.where((t) => t.status == TaskStatus.overdue).toList();
      break;
    case 5:
      filtered =
          filtered.where((t) => t.status == TaskStatus.completed).toList();
      break;
    case 6: // Birthday tab — no tasks, handled separately in UI
      filtered = [];
      break;
  }

  if (priority != null) {
    filtered = filtered.where((t) => t.priority == priority).toList();
  }

  // Sort by start date
  filtered = List.from(filtered)
    ..sort((a, b) =>
        sortAsc ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

  return filtered;
});

// ─── Today's Tasks ────────────────────────────────────────────────────────────
final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final today = DateTime.now();
  return tasks.where((t) => t.occursOnDate(today)).toList();
});

// ─── Summary Stats ────────────────────────────────────────────────────────────
final taskSummaryProvider = Provider<Map<String, int>>((ref) {
  final tasks = ref.watch(taskListProvider);
  return {
    'total': tasks.length,
    'upcoming': tasks.where((t) => t.status == TaskStatus.upcoming).length,
    'overdue': tasks.where((t) => t.status == TaskStatus.overdue).length,
    'completed': tasks.where((t) => t.status == TaskStatus.completed).length,
  };
});

// ─── Music Providers ──────────────────────────────────────────────────────────
class MusicNotifier extends StateNotifier<List<MusicModel>> {
  MusicNotifier() : super(List.from(dummyMusic));

  void toggleFavorite(String id) {
    state = [
      for (final m in state)
        if (m.id == id) m.copyWith(isFavorite: !m.isFavorite) else m,
    ];
  }

  void setDefault(String id) {
    state = [
      for (final m in state) m.copyWith(isDefault: m.id == id),
    ];
  }
}

final musicListProvider =
    StateNotifierProvider<MusicNotifier, List<MusicModel>>(
        (ref) => MusicNotifier());

final selectedMusicIdProvider = StateProvider<String>((ref) => 'm1');

final musicCategoryFilterProvider =
    StateProvider<MusicCategory?>((ref) => null);

final filteredMusicProvider = Provider<List<MusicModel>>((ref) {
  final music = ref.watch(musicListProvider);
  final filter = ref.watch(musicCategoryFilterProvider);
  if (filter == null) return music;
  return music.where((m) => m.category == filter).toList();
});

final musicPreviewPlayingProvider = StateProvider<String?>((ref) => null);

// ─── Custom (User-uploaded) Music Files ──────────────────────────────────────
class CustomMusicNotifier extends StateNotifier<List<String>> {
  CustomMusicNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final files = await StorageService.loadCustomMusicFiles();
    state = files;
  }

  Future<void> addFile(String path) async {
    if (!state.contains(path)) {
      state = [...state, path];
      await StorageService.saveCustomMusicFiles(state);
    }
  }

  Future<void> removeFile(String path) async {
    state = state.where((f) => f != path).toList();
    await StorageService.saveCustomMusicFiles(state);
  }
}

final customMusicFilesProvider =
    StateNotifierProvider<CustomMusicNotifier, List<String>>(
        (ref) => CustomMusicNotifier());

// ─── Add Task Form State ──────────────────────────────────────────────────────
class AddTaskFormNotifier extends StateNotifier<AddTaskFormState> {
  AddTaskFormNotifier() : super(AddTaskFormState.initial());

  void setTitle(String v) => state = state.copyWith(title: v);
  void setDescription(String v) => state = state.copyWith(description: v);
  void setCategory(TaskCategory v) => state = state.copyWith(category: v);

  void setDate(DateTime v) => state = state.copyWith(date: v);
  void setTime(TimeOfDay v) => state = state.copyWith(time: v);
  void setAlarmMode(AlarmMode v) => state = state.copyWith(alarmMode: v);
  void setMusicFile(String? v) => state = state.copyWith(musicFile: v);
  void setVolume(double v) => state = state.copyWith(volume: v);
  void setSnooze(int v) => state = state.copyWith(snoozeMinutes: v);

  void addReminder(String r) {
    if (!state.reminders.contains(r)) {
      state = state.copyWith(reminders: [...state.reminders, r]);
    }
  }

  void removeReminder(String r) {
    state = state.copyWith(
        reminders: state.reminders.where((x) => x != r).toList());
  }

  void toggleReminder(bool v) => state = state.copyWith(reminderEnabled: v);

  void toggleDueDate(bool v) => state = state.copyWith(dueDateEnabled: v);
  void setDueDate(DateTime v) => state = state.copyWith(dueDate: v);
  void setDueTime(TimeOfDay v) => state = state.copyWith(dueTime: v);

  void toggleDueReminder(bool v) =>
      state = state.copyWith(dueReminderEnabled: v);
  void addDueReminder(String r) {
    if (!state.dueReminders.contains(r)) {
      state = state.copyWith(dueReminders: [...state.dueReminders, r]);
    }
  }

  void removeDueReminder(String r) {
    state = state.copyWith(
        dueReminders: state.dueReminders.where((x) => x != r).toList());
  }

  void setDueAlarmMode(AlarmMode v) => state = state.copyWith(dueAlarmMode: v);
  void setDueMusicFile(String? v) => state = state.copyWith(dueMusicFile: v);
  void setDueVolume(double v) => state = state.copyWith(dueVolume: v);
  void setDueSnooze(int v) => state = state.copyWith(dueSnoozeMinutes: v);

  void setRepeat(RepeatType v) => state = state.copyWith(repeat: v);
  void toggleWeekDay(int index) {
    final days = List<bool>.from(state.weekDays);
    days[index] = !days[index];
    state = state.copyWith(weekDays: days);
  }

  void setPriority(TaskPriority v) => state = state.copyWith(priority: v);
  void setColorTag(Color v) => state = state.copyWith(colorTag: v);
  void setStatus(TaskStatus? v) =>
      state = state.copyWith(status: v, hasStatus: v != null);
  void reset() => state = AddTaskFormState.initial();
}

class AddTaskFormState {
  final String title;
  final String description;
  final TaskCategory category;
  final DateTime date;
  final TimeOfDay time;
  final AlarmMode alarmMode;
  final String? musicFile;
  final double volume;
  final int snoozeMinutes;
  final List<String> reminders;
  final bool reminderEnabled;
  final bool dueDateEnabled;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final bool dueReminderEnabled;
  final List<String> dueReminders;
  final AlarmMode dueAlarmMode;
  final String? dueMusicFile;
  final double dueVolume;
  final int dueSnoozeMinutes;
  final RepeatType repeat;
  final List<bool> weekDays;
  final TaskPriority priority;
  final Color colorTag;
  // Nullable - only set when editing an existing task
  final TaskStatus? status;
  final bool hasStatus;

  const AddTaskFormState({
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.time,
    required this.alarmMode,
    this.musicFile,
    required this.volume,
    required this.snoozeMinutes,
    required this.reminders,
    required this.reminderEnabled,
    required this.dueDateEnabled,
    this.dueDate,
    this.dueTime,
    required this.dueReminderEnabled,
    required this.dueReminders,
    required this.dueAlarmMode,
    this.dueMusicFile,
    required this.dueVolume,
    required this.dueSnoozeMinutes,
    required this.repeat,
    required this.weekDays,
    required this.priority,
    required this.colorTag,
    this.status,
    this.hasStatus = false,
  });

  factory AddTaskFormState.initial() => AddTaskFormState(
        title: '',
        description: '',
        category: TaskCategory.work,
        date: DateTime.now().add(const Duration(days: 1)),
        time: const TimeOfDay(hour: 9, minute: 0),
        alarmMode: AlarmMode.notificationOnly,
        musicFile: null,
        volume: 100,
        snoozeMinutes: 15,
        reminders: const ['1 Hour Before'],
        reminderEnabled: true,
        dueDateEnabled: false,
        dueDate: null,
        dueTime: null,
        dueReminderEnabled: false,
        dueReminders: const [],
        dueAlarmMode: AlarmMode.notificationOnly,
        dueMusicFile: null,
        dueVolume: 100,
        dueSnoozeMinutes: 15,
        repeat: RepeatType.none,
        weekDays: const [false, true, true, true, true, true, false],
        priority: TaskPriority.medium,
        colorTag: const Color(0xFF7B6EF6),
        status: null,
        hasStatus: false,
      );

  AddTaskFormState copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    DateTime? date,
    TimeOfDay? time,
    AlarmMode? alarmMode,
    String? musicFile,
    double? volume,
    int? snoozeMinutes,
    List<String>? reminders,
    bool? reminderEnabled,
    bool? dueDateEnabled,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? dueReminderEnabled,
    List<String>? dueReminders,
    AlarmMode? dueAlarmMode,
    String? dueMusicFile,
    double? dueVolume,
    int? dueSnoozeMinutes,
    RepeatType? repeat,
    List<bool>? weekDays,
    TaskPriority? priority,
    Color? colorTag,
    TaskStatus? status,
    bool? hasStatus,
  }) {
    return AddTaskFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      alarmMode: alarmMode ?? this.alarmMode,
      musicFile: musicFile ?? this.musicFile,
      volume: volume ?? this.volume,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      reminders: reminders ?? this.reminders,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      dueDateEnabled: dueDateEnabled ?? this.dueDateEnabled,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      dueReminderEnabled: dueReminderEnabled ?? this.dueReminderEnabled,
      dueReminders: dueReminders ?? this.dueReminders,
      dueAlarmMode: dueAlarmMode ?? this.dueAlarmMode,
      dueMusicFile: dueMusicFile ?? this.dueMusicFile,
      dueVolume: dueVolume ?? this.dueVolume,
      dueSnoozeMinutes: dueSnoozeMinutes ?? this.dueSnoozeMinutes,
      repeat: repeat ?? this.repeat,
      weekDays: weekDays ?? this.weekDays,
      priority: priority ?? this.priority,
      colorTag: colorTag ?? this.colorTag,
      status: status ?? this.status,
      hasStatus: hasStatus ?? this.hasStatus,
    );
  }
}

final addTaskFormProvider =
    StateNotifierProvider<AddTaskFormNotifier, AddTaskFormState>(
        (ref) => AddTaskFormNotifier());

// ─── Alarm Screen State ───────────────────────────────────────────────────────
final alarmActiveProvider = StateProvider<bool>((ref) => false);
final activeAlarmTaskIdProvider = StateProvider<String?>((ref) => null);

// ─── Settings Providers ───────────────────────────────────────────────────────
final accentColorIndexProvider = StateProvider<int>((ref) => 0);
final defaultMusicProvider = StateProvider<String>((ref) => 'alarm_clock.mp3');
final defaultVolumeProvider = StateProvider<double>((ref) => 100.0);
final defaultSnoozeProvider = StateProvider<int>((ref) => 15);
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);
final dndEnabledProvider = StateProvider<bool>((ref) => false);
final defaultReminderProvider = StateProvider<String>((ref) => '1 Hour Before');

// ── Default Notification (notificationOnly mode) ──────────────────────────────
final defaultNotifMusicProvider =
    StateProvider<String>((ref) => 'mixkit-happy-bells-notification-937.mp3');
final defaultNotifVolumeProvider = StateProvider<double>((ref) => 100.0);

// ─── Auth UI State ────────────────────────────────────────────────────────────
final isLoggedInProvider = StateProvider<bool>((ref) => false);
final currentUserNameProvider = StateProvider<String>((ref) => '');
final currentUserEmailProvider = StateProvider<String>((ref) => '');
final hasUnsyncedLocalTasksProvider = StateProvider<bool>((ref) => true);

// ─── Birthday Providers ───────────────────────────────────────────────────────

class BirthdayNotifier extends StateNotifier<List<BirthdayEntry>> {
  BirthdayNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final saved = await StorageService.loadBirthdays();
    state = saved;
    // Reschedule birthday reminders on every app start / boot so
    // notifications roll over to the next year automatically.
    for (final entry in saved) {
      await NotificationService.scheduleBirthdayReminders(entry);
    }
  }

  Future<void> _save() async {
    await StorageService.saveBirthdays(state);
  }

  Future<void> addEntry(BirthdayEntry entry) async {
    state = [...state, entry];
    await _save();
    await NotificationService.scheduleBirthdayReminders(entry);
  }

  Future<void> updateEntry(BirthdayEntry entry) async {
    state = [
      for (final e in state)
        if (e.id == entry.id) entry else e,
    ];
    await _save();
    await NotificationService.cancelBirthdayReminders(entry.id);
    await NotificationService.scheduleBirthdayReminders(entry);
  }

  Future<void> deleteEntry(String id) async {
    await NotificationService.cancelBirthdayReminders(id);
    state = state.where((e) => e.id != id).toList();
    await _save();
  }
}

final birthdayListProvider =
    StateNotifierProvider<BirthdayNotifier, List<BirthdayEntry>>(
        (ref) => BirthdayNotifier());

/// true = user clicked "I've filled in my birthday data" — badge never shows again.
final birthdayBadgePermanentlyDismissedProvider =
    StateProvider<bool>((ref) => false);

// ─── Dynamic Public Holidays ──────────────────────────────────────────────────

/// Holds the detected country code and the fetched public holidays.
class HolidayState {
  final String countryCode;
  final List<GlobalEvent> holidays;

  const HolidayState({
    required this.countryCode,
    required this.holidays,
  });

  HolidayState copyWith({
    String? countryCode,
    List<GlobalEvent>? holidays,
  }) =>
      HolidayState(
        countryCode: countryCode ?? this.countryCode,
        holidays: holidays ?? this.holidays,
      );
}

class HolidayNotifier extends AsyncNotifier<HolidayState> {
  @override
  Future<HolidayState> build() async {
    final countryCode = await HolidayService.detectCountryCode();
    final holidays = await HolidayService.fetchRelevantHolidays(countryCode);
    return HolidayState(countryCode: countryCode, holidays: holidays);
  }

  /// Call this from settings to re-detect the country (e.g. after the user
  /// moves to a different country or grants location permission later).
  Future<void> refresh({bool resetCountry = false}) async {
    if (resetCountry) await HolidayService.resetCountryCache();
    ref.invalidateSelf();
  }
}

final holidayProvider = AsyncNotifierProvider<HolidayNotifier, HolidayState>(
    () => HolidayNotifier());

// ─── Pomodoro Timer Provider ──────────────────────────────────────────────────

class PomodoroNotifier extends StateNotifier<PomodoroTimerState> {
  PomodoroNotifier() : super(const PomodoroTimerState()) {
    _loadSettings();
    _loadTodaySessions();
  }

  Timer? _timer;

  Future<void> _loadSettings() async {
    final saved = await StorageService.loadPomodoroSettings();
    state = state.copyWith(settings: saved);
  }

  Future<void> _saveSettings() async {
    await StorageService.savePomodoroSettings(state.settings);
  }

  Future<void> _loadTodaySessions() async {
    final sessions = await StorageService.loadPomodoroSessions();
    final today = DateTime.now();
    final todaySessions = sessions.where((s) {
      final sessionDate = DateTime(
          s.startTime.year, s.startTime.month, s.startTime.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      return sessionDate == todayDate;
    }).toList();
    state = state.copyWith(
      allSessions: sessions,
      todaySessions: todaySessions,
      completedWorkSessions: todaySessions
          .where((s) => s.type == PomodoroSessionType.work && s.completed)
          .length,
    );
  }

  Future<void> _saveSessions() async {
    await StorageService.savePomodoroSessions(state.allSessions);
  }

  void startWork() {
    _timer?.cancel();
    AudioService.instance.stop(); // Stop alarm sound if playing
    state = state.copyWith(
      state: PomodoroState.working,
      remainingSeconds: state.settings.workDuration * 60,
      sessionStartTime: DateTime.now(),
      clearPausedAt: true,
    );
    _startTimer();
  }

  void startShortBreak() {
    _timer?.cancel();
    AudioService.instance.stop(); // Stop alarm sound if playing
    state = state.copyWith(
      state: PomodoroState.shortBreak,
      remainingSeconds: state.settings.shortBreakDuration * 60,
      sessionStartTime: DateTime.now(),
      clearPausedAt: true,
    );
    _startTimer();
  }

  void startLongBreak() {
    _timer?.cancel();
    AudioService.instance.stop(); // Stop alarm sound if playing
    state = state.copyWith(
      state: PomodoroState.longBreak,
      remainingSeconds: state.settings.longBreakDuration * 60,
      sessionStartTime: DateTime.now(),
      clearPausedAt: true,
    );
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(
      state: PomodoroState.paused,
      pausedAt: DateTime.now(),
    );
  }

  void resume() {
    if (state.state == PomodoroState.paused) {
      final previousState =
          state.isBreak ? state.state : PomodoroState.working;
      state = state.copyWith(
        state: previousState,
        clearPausedAt: true,
      );
      _startTimer();
    }
  }

  void reset() {
    _timer?.cancel();
    AudioService.instance.stop(); // Stop alarm sound if playing
    state = state.copyWith(
      state: PomodoroState.idle,
      remainingSeconds: 0,
      clearSessionStartTime: true,
      clearPausedAt: true,
    );
  }

  void skip() {
    _timer?.cancel();
    AudioService.instance.stop(); // Stop alarm sound if playing
    _completeCurrentSession(completed: false);
    _autoStartNext();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _completeCurrentSession(completed: true);

    // Play alarm sound
    AudioService.instance.playAsset(
      state.settings.alarmSound,
      volume: state.settings.alarmVolume / 100.0,
    );

    // Show notification
    NotificationService.showPomodoroNotification(
      title: state.isBreak ? 'Break Complete!' : 'Focus Session Complete!',
      body: state.isBreak
          ? 'Time to get back to work 💪'
          : 'Great job! Take a break 🎉',
    );

    _autoStartNext();
  }

  void _completeCurrentSession({required bool completed}) {
    if (state.sessionStartTime == null) return;

    final sessionType = state.state == PomodoroState.working
        ? PomodoroSessionType.work
        : (state.state == PomodoroState.shortBreak
            ? PomodoroSessionType.shortBreak
            : PomodoroSessionType.longBreak);

    final duration = state.state == PomodoroState.working
        ? state.settings.workDuration
        : (state.state == PomodoroState.shortBreak
            ? state.settings.shortBreakDuration
            : state.settings.longBreakDuration);

    final session = PomodoroSession(
      startTime: state.sessionStartTime!,
      endTime: DateTime.now(),
      type: sessionType,
      durationMinutes: duration,
      completed: completed,
    );

    final updatedTodaySessions = [...state.todaySessions, session];
    final updatedAllSessions = [...state.allSessions, session];
    state = state.copyWith(
      todaySessions: updatedTodaySessions,
      allSessions: updatedAllSessions,
      completedWorkSessions: sessionType == PomodoroSessionType.work && completed
          ? state.completedWorkSessions + 1
          : state.completedWorkSessions,
    );

    _saveSessions();
  }

  void _autoStartNext() {
    if (state.state == PomodoroState.working) {
      // After work session
      if (state.completedWorkSessions % state.settings.sessionsBeforeLongBreak == 0) {
        // Long break
        if (state.settings.autoStartBreaks) {
          startLongBreak();
        } else {
          state = state.copyWith(
            state: PomodoroState.idle,
            remainingSeconds: state.settings.longBreakDuration * 60,
            clearSessionStartTime: true,
          );
        }
      } else {
        // Short break
        if (state.settings.autoStartBreaks) {
          startShortBreak();
        } else {
          state = state.copyWith(
            state: PomodoroState.idle,
            remainingSeconds: state.settings.shortBreakDuration * 60,
            clearSessionStartTime: true,
          );
        }
      }
    } else {
      // After break
      if (state.settings.autoStartPomodoros) {
        startWork();
      } else {
        state = state.copyWith(
          state: PomodoroState.idle,
          remainingSeconds: state.settings.workDuration * 60,
          clearSessionStartTime: true,
        );
      }
    }
  }

  void updateSettings(PomodoroSettings settings) {
    state = state.copyWith(settings: settings);
    _saveSettings();
  }

  Future<void> deleteSession(PomodoroSession session) async {
    final updatedAllSessions = state.allSessions.where((s) => s != session).toList();

    // Update today's sessions as well
    final today = DateTime.now();
    final todaySessions = updatedAllSessions.where((s) {
      final sessionDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final todayDate = DateTime(today.year, today.month, today.day);
      return sessionDate == todayDate;
    }).toList();

    state = state.copyWith(
      allSessions: updatedAllSessions,
      todaySessions: todaySessions,
      completedWorkSessions: todaySessions
          .where((s) => s.type == PomodoroSessionType.work && s.completed)
          .length,
    );
    await _saveSessions();
  }

  Future<void> clearAllSessions() async {
    state = state.copyWith(
      allSessions: [],
      todaySessions: [],
      completedWorkSessions: 0,
    );
    await _saveSessions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final pomodoroProvider =
    StateNotifierProvider<PomodoroNotifier, PomodoroTimerState>(
        (ref) => PomodoroNotifier());
