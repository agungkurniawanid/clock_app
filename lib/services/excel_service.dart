import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task_model.dart';

class ExcelService {
  static const _sheetName = 'Tasks';

  // Column order must match _rowToTask parsing
  static const List<String> _headers = [
    'ID',
    'Title',
    'Description',
    'Category',
    'Status',
    'Priority',
    'Date',
    'Time Hour',
    'Time Minute',
    'Alarm Mode',
    'Music File',
    'Volume',
    'Snooze Minutes',
    'Due Date Enabled',
    'Due Date',
    'Due Time Hour',
    'Due Time Minute',
    'Due Reminder Enabled',
    'Due Reminders',
    'Due Alarm Mode',
    'Due Music File',
    'Due Volume',
    'Due Snooze Minutes',
    'Repeat',
    'Week Days',
    'Custom Interval',
    'Custom Interval Unit',
    'Custom End Type',
    'Custom End Date',
    'Custom End After Count',
    'Custom Week Days',
    'Reminders',
    'Color Tag',
    'Auto Complete On Checklist',
    'Checklist',
    'Sub Tasks',
    'History',
  ];

  // ── Export ──────────────────────────────────────────────────────────────────

  /// Export [tasks] to an .xlsx file and open the system share/save sheet.
  static Future<void> exportTasks(List<TaskModel> tasks) async {
    final excel = Excel.createExcel();

    // Create our named sheet and remove the default 'Sheet1'
    excel[_sheetName]; // creates 'Tasks' sheet
    for (final key in excel.sheets.keys.toList()) {
      if (key != _sheetName) excel.delete(key);
    }
    final sheet = excel[_sheetName];

    // Header row
    sheet.appendRow(_headers.map((h) => TextCellValue(h)).toList());

    // Style header cells bold
    for (int i = 0; i < _headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data rows
    for (final task in tasks) {
      sheet.appendRow(_taskToRow(task));
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');

    final dir = await getTemporaryDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final filePath = '${dir.path}/tasks_export_$timestamp.xlsx';
    await File(filePath).writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          filePath,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'Smart Alarm – Export Tasks',
    );
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Open a file picker, parse the selected .xlsx file, and return a list of
  /// [TaskModel]. Returns `null` if the user cancelled the picker.
  static Future<List<TaskModel>?> importTasks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final fileBytes = result.files.first.bytes;
    if (fileBytes == null) {
      final path = result.files.first.path;
      if (path == null) throw Exception('Cannot read file');
      final bytes = await File(path).readAsBytes();
      return _parseExcel(bytes);
    }
    return _parseExcel(fileBytes);
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  static List<TaskModel> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);

    // Try the known sheet name first, otherwise fall back to first sheet
    final sheet = excel.tables[_sheetName] ?? excel.tables.values.firstOrNull;
    if (sheet == null) return [];

    final rows = sheet.rows;
    if (rows.length < 2) return []; // header only or empty

    final tasks = <TaskModel>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final id = _str(row, 0);
      if (id.isEmpty && _str(row, 1).isEmpty) continue; // blank row
      try {
        tasks.add(_rowToTask(row));
      } catch (_) {
        // Skip rows that cannot be parsed
      }
    }
    return tasks;
  }

  static List<CellValue?> _taskToRow(TaskModel task) {
    return [
      // 0  ID
      TextCellValue(task.id),
      // 1  Title
      TextCellValue(task.title),
      // 2  Description
      TextCellValue(task.description),
      // 3  Category
      TextCellValue(task.category.name),
      // 4  Status
      TextCellValue(task.status.name),
      // 5  Priority
      TextCellValue(task.priority.name),
      // 6  Date
      TextCellValue(_fmtDate(task.date)),
      // 7  Time Hour
      IntCellValue(task.time.hour),
      // 8  Time Minute
      IntCellValue(task.time.minute),
      // 9  Alarm Mode
      TextCellValue(task.alarmMode.name),
      // 10 Music File
      TextCellValue(task.musicFile ?? ''),
      // 11 Volume
      IntCellValue(task.volume),
      // 12 Snooze Minutes
      IntCellValue(task.snoozeMinutes),
      // 13 Due Date Enabled
      TextCellValue(task.dueDateEnabled ? 'TRUE' : 'FALSE'),
      // 14 Due Date
      TextCellValue(task.dueDate != null ? _fmtDate(task.dueDate!) : ''),
      // 15 Due Time Hour
      task.dueTime != null
          ? IntCellValue(task.dueTime!.hour)
          : TextCellValue(''),
      // 16 Due Time Minute
      task.dueTime != null
          ? IntCellValue(task.dueTime!.minute)
          : TextCellValue(''),
      // 17 Due Reminder Enabled
      TextCellValue(task.dueReminderEnabled ? 'TRUE' : 'FALSE'),
      // 18 Due Reminders
      TextCellValue(task.dueReminders.join(';')),
      // 19 Due Alarm Mode
      TextCellValue(task.dueAlarmMode.name),
      // 20 Due Music File
      TextCellValue(task.dueMusicFile ?? ''),
      // 21 Due Volume
      IntCellValue(task.dueVolume),
      // 22 Due Snooze Minutes
      IntCellValue(task.dueSnoozeMinutes),
      // 23 Repeat
      TextCellValue(task.repeat.name),
      // 24 Week Days (Sun,Mon,...)
      TextCellValue(_boolListToDays(task.weekDays)),
      // 25 Custom Interval
      IntCellValue(task.customInterval),
      // 26 Custom Interval Unit
      TextCellValue(task.customIntervalUnit),
      // 27 Custom End Type
      TextCellValue(task.customEndType),
      // 28 Custom End Date
      TextCellValue(
          task.customEndDate != null ? _fmtDate(task.customEndDate!) : ''),
      // 29 Custom End After Count
      IntCellValue(task.customEndAfterCount),
      // 30 Custom Week Days
      TextCellValue(_boolListToDays(task.customWeekDays)),
      // 31 Reminders
      TextCellValue(task.reminders.join(';')),
      // 32 Color Tag
      TextCellValue(_colorToHex(task.colorTag)),
      // 33 Auto Complete On Checklist
      TextCellValue(task.autoCompleteOnChecklist ? 'TRUE' : 'FALSE'),
      // 34 Checklist (JSON)
      TextCellValue(jsonEncode(task.checklist.map((c) => c.toJson()).toList())),
      // 35 Sub Tasks (JSON)
      TextCellValue(jsonEncode(task.subTasks.map((s) => s.toJson()).toList())),
      // 36 History
      TextCellValue(task.history.join(';')),
    ];
  }

  static TaskModel _rowToTask(List<Data?> row) {
    final id = _str(row, 0).isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : _str(row, 0);

    // Due time: only set if both hour and minute cells are non-empty integers
    TimeOfDay? dueTime;
    final dtHStr = _str(row, 15);
    final dtMStr = _str(row, 16);
    if (dtHStr.isNotEmpty && dtMStr.isNotEmpty) {
      final h = int.tryParse(dtHStr);
      final m = int.tryParse(dtMStr);
      if (h != null && m != null) dueTime = TimeOfDay(hour: h, minute: m);
    }

    // Checklist
    List<ChecklistItem> checklist = [];
    final checklistStr = _str(row, 34);
    if (checklistStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(checklistStr) as List<dynamic>;
        checklist = decoded
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Sub tasks
    List<SubTask> subTasks = [];
    final subTasksStr = _str(row, 35);
    if (subTasksStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(subTasksStr) as List<dynamic>;
        subTasks = decoded
            .map((e) => SubTask.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return TaskModel(
      id: id,
      title: _str(row, 1),
      description: _str(row, 2),
      category:
          _parseEnum(TaskCategory.values, _str(row, 3), TaskCategory.other),
      status: _parseEnum(TaskStatus.values, _str(row, 4), TaskStatus.todo),
      priority:
          _parseEnum(TaskPriority.values, _str(row, 5), TaskPriority.medium),
      date: DateTime.tryParse(_str(row, 6)) ?? DateTime.now(),
      time: TimeOfDay(
        hour: _int(row, 7),
        minute: _int(row, 8),
      ),
      alarmMode: _parseEnum(
          AlarmMode.values, _str(row, 9), AlarmMode.notificationOnly),
      musicFile: _str(row, 10).isEmpty ? null : _str(row, 10),
      volume: _int(row, 11).clamp(0, 100),
      snoozeMinutes: _int(row, 12),
      dueDateEnabled: _str(row, 13).toUpperCase() == 'TRUE',
      dueDate:
          _str(row, 14).isNotEmpty ? DateTime.tryParse(_str(row, 14)) : null,
      dueTime: dueTime,
      dueReminderEnabled: _str(row, 17).toUpperCase() == 'TRUE',
      dueReminders: _splitSemicolon(_str(row, 18)),
      dueAlarmMode: _parseEnum(
          AlarmMode.values, _str(row, 19), AlarmMode.notificationOnly),
      dueMusicFile: _str(row, 20).isEmpty ? null : _str(row, 20),
      dueVolume: _int(row, 21).clamp(0, 100),
      dueSnoozeMinutes: _int(row, 22),
      repeat: _parseEnum(RepeatType.values, _str(row, 23), RepeatType.none),
      weekDays: _parseDays(_str(row, 24)),
      customInterval: _int(row, 25).clamp(1, 999),
      customIntervalUnit: _str(row, 26).isEmpty ? 'Days' : _str(row, 26),
      customEndType: _str(row, 27).isEmpty ? 'Never' : _str(row, 27),
      customEndDate:
          _str(row, 28).isNotEmpty ? DateTime.tryParse(_str(row, 28)) : null,
      customEndAfterCount: _int(row, 29).clamp(1, 9999),
      customWeekDays: _parseDays(_str(row, 30)),
      reminders: _splitSemicolon(_str(row, 31)),
      colorTag: _parseColor(_str(row, 32)),
      autoCompleteOnChecklist: _str(row, 33).toUpperCase() == 'TRUE',
      checklist: checklist,
      subTasks: subTasks,
      history: _splitSemicolon(_str(row, 36)),
    );
  }

  // ── Low-level cell helpers ─────────────────────────────────────────────────

  static String _str(List<Data?> row, int index) {
    if (index >= row.length) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  static int _int(List<Data?> row, int index) {
    return int.tryParse(_str(row, index)) ?? 0;
  }

  static T _parseEnum<T extends Enum>(List<T> values, String name, T fallback) {
    return values.firstWhere((e) => e.name == name, orElse: () => fallback);
  }

  static List<String> _splitSemicolon(String s) =>
      s.isEmpty ? [] : s.split(';').where((p) => p.isNotEmpty).toList();

  // ── Date / time helpers ────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Week-days helpers ──────────────────────────────────────────────────────

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  static String _boolListToDays(List<bool> days) {
    final result = <String>[];
    for (int i = 0; i < days.length && i < _dayNames.length; i++) {
      if (days[i]) result.add(_dayNames[i]);
    }
    return result.join(',');
  }

  static List<bool> _parseDays(String s) {
    if (s.isEmpty) return List.filled(7, false);
    final active = s.split(',').map((e) => e.trim()).toSet();
    return _dayNames.map((n) => active.contains(n)).toList();
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  static String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#'
            '${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static Color _parseColor(String hex) {
    try {
      final s = hex.replaceAll('#', '');
      if (s.length == 6) return Color(int.parse('FF$s', radix: 16));
      if (s.length == 8) return Color(int.parse(s, radix: 16));
    } catch (_) {}
    return const Color(0xFF9C27B0);
  }
}
