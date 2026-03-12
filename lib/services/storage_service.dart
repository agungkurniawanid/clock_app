import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../models/birthday_model.dart';
import '../models/habit_model.dart';
import '../models/note_model.dart';
import '../models/pomodoro_model.dart';
import '../models/notification_item.dart';

/// Persists tasks and app settings to SharedPreferences.
class StorageService {
  static const _tasksKey = 'tasks_v2';
  static const _themeModeKey = 'theme_mode';
  static const _defaultMusicKey = 'default_music';
  static const _defaultVolumeKey = 'default_volume';
  static const _defaultSnoozeKey = 'default_snooze';
  static const _vibrationKey = 'vibration_enabled';
  static const _dndKey = 'dnd_enabled';
  static const _accentColorKey = 'accent_color_index';
  static const _defaultReminderKey = 'default_reminder';
  static const _customMusicFilesKey = 'custom_music_files';
  static const _isLoggedInKey = 'auth_is_logged_in';
  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';
  static const _hasUnsyncedKey = 'auth_has_unsynced';
  static const _defaultNotifMusicKey = 'default_notif_music';
  static const _defaultNotifVolumeKey = 'default_notif_volume';
  static const _birthdaysKey = 'birthdays_v1';
  static const _birthdayBadgeDismissedKey = 'birthday_badge_dismissed';
  static const _pomodoroSettingsKey = 'pomodoro_settings';
  static const _pomodoroSessionsKey = 'pomodoro_sessions';
  static const _notificationsKey = 'in_app_notifications_v1';
  static const _fontScaleIndexKey = 'font_scale_index';
  static const _habitsKey = 'habits_v1';
  static const _noteFoldersKey = 'note_folders_v1';
  static const _noteFilesKey = 'note_files_v1';

  // ── Tasks ─────────────────────────────────────────────────────────────────
  static Future<void> saveTasks(List<TaskModel> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final list = tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tasksKey, list);
  }

  static Future<List<TaskModel>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_tasksKey);
    if (list == null) return [];
    try {
      return list
          .map((s) => TaskModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_themeModeKey);
    if (idx == null) return ThemeMode.light;
    return ThemeMode.values[idx.clamp(0, ThemeMode.values.length - 1)];
  }

  static Future<void> saveDefaultMusic(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultMusicKey, fileName);
  }

  static Future<String> loadDefaultMusic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultMusicKey) ?? 'alarm_clock.mp3';
  }

  static Future<void> saveDefaultVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultVolumeKey, volume);
  }

  static Future<double> loadDefaultVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_defaultVolumeKey) ?? 100.0;
  }

  static Future<void> saveDefaultSnooze(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultSnoozeKey, minutes);
  }

  static Future<int> loadDefaultSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultSnoozeKey) ?? 15;
  }

  static Future<void> saveVibration(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, enabled);
  }

  static Future<bool> loadVibration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey) ?? true;
  }

  static Future<void> saveDnd(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dndKey, enabled);
  }

  static Future<bool> loadDnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dndKey) ?? false;
  }

  static Future<void> saveAccentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, index);
  }

  static Future<int> loadAccentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey) ?? 0;
  }

  static Future<void> saveFontScaleIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontScaleIndexKey, index);
  }

  /// Returns persisted font scale index. Default 1 = Normal (1.0×).
  /// 0 = Small (0.85×), 1 = Normal (1.0×), 2 = Large (1.15×), 3 = XLarge (1.3×)
  static Future<int> loadFontScaleIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fontScaleIndexKey) ?? 0;
  }

  static Future<void> saveDefaultReminder(String reminder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultReminderKey, reminder);
  }

  static Future<String> loadDefaultReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultReminderKey) ?? '1 Hour Before';
  }

  // ── Default Notification Music / Volume ───────────────────────────────────
  static Future<void> saveDefaultNotifMusic(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultNotifMusicKey, fileName);
  }

  static Future<String> loadDefaultNotifMusic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultNotifMusicKey) ??
        'mixkit-happy-bells-notification-937.mp3';
  }

  static Future<void> saveDefaultNotifVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultNotifVolumeKey, volume);
  }

  static Future<double> loadDefaultNotifVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_defaultNotifVolumeKey) ?? 100.0;
  }

  // ── Custom Music Files ────────────────────────────────────────────────────
  static Future<void> saveCustomMusicFiles(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customMusicFilesKey, paths);
  }

  static Future<List<String>> loadCustomMusicFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customMusicFilesKey) ?? [];
  }

  static Future<void> addCustomMusicFile(String path) async {
    final existing = await loadCustomMusicFiles();
    if (!existing.contains(path)) {
      existing.add(path);
      await saveCustomMusicFiles(existing);
    }
  }

  // ── Auth Session ──────────────────────────────────────────────────────────
  static Future<void> saveAuthState({
    required bool isLoggedIn,
    required String userName,
    required String userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, isLoggedIn);
    await prefs.setString(_userNameKey, userName);
    await prefs.setString(_userEmailKey, userEmail);
  }

  static Future<Map<String, dynamic>> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool(_isLoggedInKey) ?? false,
      'userName': prefs.getString(_userNameKey) ?? '',
      'userEmail': prefs.getString(_userEmailKey) ?? '',
    };
  }

  static Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
  }

  static Future<void> saveHasUnsynced(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasUnsyncedKey, value);
  }

  static Future<bool> loadHasUnsynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasUnsyncedKey) ?? true;
  }

  // ── Birthdays ──────────────────────────────────────────────────────────────
  static Future<void> saveBirthdays(List<BirthdayEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final list = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_birthdaysKey, list);
  }

  static Future<List<BirthdayEntry>> loadBirthdays() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_birthdaysKey);
    if (list == null) return [];
    try {
      return list
          .map((s) =>
              BirthdayEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBirthdayBadgeDismissed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_birthdayBadgeDismissedKey, value);
  }

  static Future<bool> loadBirthdayBadgeDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_birthdayBadgeDismissedKey) ?? false;
  }

  // ── Pomodoro Timer ─────────────────────────────────────────────────────────
  static Future<void> savePomodoroSettings(PomodoroSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pomodoroSettingsKey, jsonEncode(settings.toJson()));
  }

  static Future<PomodoroSettings> loadPomodoroSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_pomodoroSettingsKey);
    if (str == null) return const PomodoroSettings();
    try {
      return PomodoroSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return const PomodoroSettings();
    }
  }

  static Future<void> savePomodoroSessions(
      List<PomodoroSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final list = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_pomodoroSessionsKey, list);
  }

  static Future<List<PomodoroSession>> loadPomodoroSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pomodoroSessionsKey);
    if (list == null) return [];
    try {
      return list
          .map((s) =>
              PomodoroSession.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── In-App Notifications ───────────────────────────────────────────────────
  static Future<void> saveNotifications(List<NotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final list = items.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_notificationsKey, list);
  }

  static Future<List<NotificationItem>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notificationsKey);
    if (list == null) return [];
    try {
      return list
          .map((s) =>
              NotificationItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Habits ─────────────────────────────────────────────────────────────────
  static Future<void> saveHabits(List<HabitModel> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final list = habits.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList(_habitsKey, list);
  }

  static Future<List<HabitModel>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_habitsKey);
    if (list == null) return [];
    try {
      return list
          .map(
              (s) => HabitModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  static Future<void> saveNoteFolders(List<NoteFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _noteFoldersKey,
      folders.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  static Future<List<NoteFolder>> loadNoteFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_noteFoldersKey);
    if (list == null) return [];
    try {
      return list
          .map((s) => NoteFolder.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNoteFiles(List<NoteFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _noteFilesKey,
      files.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  static Future<List<NoteFile>> loadNoteFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_noteFilesKey);
    if (list == null) return [];
    try {
      return list
          .map((s) => NoteFile.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }
}