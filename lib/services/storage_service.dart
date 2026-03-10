import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../models/birthday_model.dart';

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
    return prefs.getString(_defaultNotifMusicKey) ?? 'alarm_clock.mp3';
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

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }
}
