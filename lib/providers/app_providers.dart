import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dummy_data.dart';
import '../models/task_model.dart';
import '../models/music_model.dart';

// ─── Theme Provider ───────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ─── Navigation Index ─────────────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─── Onboarding ───────────────────────────────────────────────────────────────
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

// ─── Task Providers ───────────────────────────────────────────────────────────
class TaskNotifier extends StateNotifier<List<TaskModel>> {
  TaskNotifier() : super(List.from(dummyTasks));

  void addTask(TaskModel task) => state = [...state, task];

  void updateTask(TaskModel task) {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];
  }

  void deleteTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void markComplete(String id) {
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

final taskTabIndexProvider =
    StateProvider<int>((ref) => 0); // 0=All,1=Upcoming,2=Risk,3=Overdue,4=Done

final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final query = ref.watch(taskSearchQueryProvider).toLowerCase();
  final tabIndex = ref.watch(taskTabIndexProvider);

  var filtered = tasks;

  if (query.isNotEmpty) {
    filtered = filtered
        .where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query))
        .toList();
  }

  switch (tabIndex) {
    case 1: // Upcoming
      filtered = filtered.where((t) => t.status == TaskStatus.todo).toList();
      break;
    case 2: // Risk
      filtered = filtered.where((t) => t.status == TaskStatus.risk).toList();
      break;
    case 3: // Overdue
      filtered = filtered.where((t) => t.status == TaskStatus.overdue).toList();
      break;
    case 4: // Done
      filtered =
          filtered.where((t) => t.status == TaskStatus.completed).toList();
      break;
  }

  return filtered;
});

// ─── Today's Tasks ────────────────────────────────────────────────────────────
final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref.watch(taskListProvider);
  final today = DateTime.now();
  return tasks
      .where((t) =>
          t.date.year == today.year &&
          t.date.month == today.month &&
          t.date.day == today.day)
      .toList();
});

// ─── Summary Stats ────────────────────────────────────────────────────────────
final taskSummaryProvider = Provider<Map<String, int>>((ref) {
  final tasks = ref.watch(taskListProvider);
  return {
    'total': tasks.length,
    'upcoming': tasks.where((t) => t.status == TaskStatus.todo).length,
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

final musicPreviewPlayingProvider = StateProvider<bool>((ref) => false);

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
  void setRepeat(RepeatType v) => state = state.copyWith(repeat: v);
  void toggleWeekDay(int index) {
    final days = List<bool>.from(state.weekDays);
    days[index] = !days[index];
    state = state.copyWith(weekDays: days);
  }

  void addReminder(String r) {
    if (!state.reminders.contains(r)) {
      state = state.copyWith(reminders: [...state.reminders, r]);
    }
  }

  void removeReminder(String r) {
    state = state.copyWith(
      reminders: state.reminders.where((x) => x != r).toList(),
    );
  }

  void toggleReminder(bool v) => state = state.copyWith(reminderEnabled: v);
  void setPriority(TaskPriority v) => state = state.copyWith(priority: v);
  void setColorTag(Color v) => state = state.copyWith(colorTag: v);
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
  final RepeatType repeat;
  final List<bool> weekDays;
  final List<String> reminders;
  final bool reminderEnabled;
  final TaskPriority priority;
  final Color colorTag;

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
    required this.repeat,
    required this.weekDays,
    required this.reminders,
    required this.reminderEnabled,
    required this.priority,
    required this.colorTag,
  });

  factory AddTaskFormState.initial() => AddTaskFormState(
        title: '',
        description: '',
        category: TaskCategory.work,
        date: DateTime.now().add(const Duration(days: 1)),
        time: const TimeOfDay(hour: 9, minute: 0),
        alarmMode: AlarmMode.notificationOnly,
        musicFile: null,
        volume: 75,
        snoozeMinutes: 15,
        repeat: RepeatType.none,
        weekDays: [false, true, true, true, true, true, false],
        reminders: ['1 Hour Before'],
        reminderEnabled: true,
        priority: TaskPriority.medium,
        colorTag: const Color(0xFF7B6EF6),
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
    RepeatType? repeat,
    List<bool>? weekDays,
    List<String>? reminders,
    bool? reminderEnabled,
    TaskPriority? priority,
    Color? colorTag,
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
      repeat: repeat ?? this.repeat,
      weekDays: weekDays ?? this.weekDays,
      reminders: reminders ?? this.reminders,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      priority: priority ?? this.priority,
      colorTag: colorTag ?? this.colorTag,
    );
  }
}

final addTaskFormProvider =
    StateNotifierProvider<AddTaskFormNotifier, AddTaskFormState>(
        (ref) => AddTaskFormNotifier());

// ─── Alarm Screen State ───────────────────────────────────────────────────────
final alarmActiveProvider = StateProvider<bool>((ref) => false);

final activeAlarmTaskIdProvider = StateProvider<String?>((ref) => '1');

// ─── Settings Providers ───────────────────────────────────────────────────────
final accentColorIndexProvider =
    StateProvider<int>((ref) => 0); // 0=purple, 1=teal, 2=pink, 3=blue

final defaultMusicProvider = StateProvider<String>((ref) => 'lofi_morning.mp3');

final defaultVolumeProvider = StateProvider<double>((ref) => 75.0);

final defaultSnoozeProvider = StateProvider<int>((ref) => 15);

final vibrationEnabledProvider = StateProvider<bool>((ref) => true);

final dndEnabledProvider = StateProvider<bool>((ref) => false);
