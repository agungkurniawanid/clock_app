import 'package:flutter/material.dart';

enum PomodoroState { idle, working, shortBreak, longBreak, paused }

enum PomodoroSessionType { work, shortBreak, longBreak }

class PomodoroSession {
  final DateTime startTime;
  final DateTime? endTime;
  final PomodoroSessionType type;
  final int durationMinutes;
  final bool completed;

  const PomodoroSession({
    required this.startTime,
    this.endTime,
    required this.type,
    required this.durationMinutes,
    this.completed = false,
  });

  PomodoroSession copyWith({
    DateTime? startTime,
    DateTime? endTime,
    PomodoroSessionType? type,
    int? durationMinutes,
    bool? completed,
  }) =>
      PomodoroSession(
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        type: type ?? this.type,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'type': type.index,
        'durationMinutes': durationMinutes,
        'completed': completed,
      };

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      type: PomodoroSessionType.values[json['type'] as int],
      durationMinutes: json['durationMinutes'] as int,
      completed: json['completed'] as bool? ?? false,
    );
  }

  String get typeLabel {
    switch (type) {
      case PomodoroSessionType.work:
        return 'Work';
      case PomodoroSessionType.shortBreak:
        return 'Short Break';
      case PomodoroSessionType.longBreak:
        return 'Long Break';
    }
  }
}

class PomodoroSettings {
  final int workDuration; // in minutes
  final int shortBreakDuration; // in minutes
  final int longBreakDuration; // in minutes
  final int sessionsBeforeLongBreak;
  final bool autoStartBreaks;
  final bool autoStartPomodoros;
  final String alarmSound;
  final double alarmVolume;

  const PomodoroSettings({
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
    this.autoStartPomodoros = false,
    this.alarmSound = 'alarm_clock.mp3',
    this.alarmVolume = 100.0,
  });

  PomodoroSettings copyWith({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? sessionsBeforeLongBreak,
    bool? autoStartBreaks,
    bool? autoStartPomodoros,
    String? alarmSound,
    double? alarmVolume,
  }) =>
      PomodoroSettings(
        workDuration: workDuration ?? this.workDuration,
        shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
        longBreakDuration: longBreakDuration ?? this.longBreakDuration,
        sessionsBeforeLongBreak:
            sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
        autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
        autoStartPomodoros: autoStartPomodoros ?? this.autoStartPomodoros,
        alarmSound: alarmSound ?? this.alarmSound,
        alarmVolume: alarmVolume ?? this.alarmVolume,
      );

  Map<String, dynamic> toJson() => {
        'workDuration': workDuration,
        'shortBreakDuration': shortBreakDuration,
        'longBreakDuration': longBreakDuration,
        'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
        'autoStartBreaks': autoStartBreaks,
        'autoStartPomodoros': autoStartPomodoros,
        'alarmSound': alarmSound,
        'alarmVolume': alarmVolume,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      workDuration: json['workDuration'] as int? ?? 25,
      shortBreakDuration: json['shortBreakDuration'] as int? ?? 5,
      longBreakDuration: json['longBreakDuration'] as int? ?? 15,
      sessionsBeforeLongBreak: json['sessionsBeforeLongBreak'] as int? ?? 4,
      autoStartBreaks: json['autoStartBreaks'] as bool? ?? false,
      autoStartPomodoros: json['autoStartPomodoros'] as bool? ?? false,
      alarmSound: json['alarmSound'] as String? ?? 'alarm_clock.mp3',
      alarmVolume: json['alarmVolume'] as double? ?? 100.0,
    );
  }
}

class PomodoroTimerState {
  final PomodoroState state;
  final int remainingSeconds;
  final int completedWorkSessions; // for today
  final DateTime? sessionStartTime;
  final DateTime? pausedAt;
  final DateTime?
      targetEndTime; // waktu selesai yang diharapkan (untuk akurasi background)
  final PomodoroState? stateBeforePause; // untuk restore state saat resume
  final bool isAlarmRinging; // alarm sedang berbunyi setelah sesi selesai
  final List<PomodoroSession> todaySessions;
  final List<PomodoroSession> allSessions; // all historical sessions
  final PomodoroSettings settings;

  const PomodoroTimerState({
    this.state = PomodoroState.idle,
    this.remainingSeconds = 0,
    this.completedWorkSessions = 0,
    this.sessionStartTime,
    this.pausedAt,
    this.targetEndTime,
    this.stateBeforePause,
    this.isAlarmRinging = false,
    this.todaySessions = const [],
    this.allSessions = const [],
    this.settings = const PomodoroSettings(),
  });

  PomodoroTimerState copyWith({
    PomodoroState? state,
    int? remainingSeconds,
    int? completedWorkSessions,
    DateTime? sessionStartTime,
    DateTime? pausedAt,
    DateTime? targetEndTime,
    bool clearPausedAt = false,
    bool clearSessionStartTime = false,
    bool clearTargetEndTime = false,
    PomodoroState? stateBeforePause,
    bool clearStateBeforePause = false,
    bool? isAlarmRinging,
    List<PomodoroSession>? todaySessions,
    List<PomodoroSession>? allSessions,
    PomodoroSettings? settings,
  }) =>
      PomodoroTimerState(
        state: state ?? this.state,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        completedWorkSessions:
            completedWorkSessions ?? this.completedWorkSessions,
        sessionStartTime: clearSessionStartTime
            ? null
            : (sessionStartTime ?? this.sessionStartTime),
        pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
        targetEndTime:
            clearTargetEndTime ? null : (targetEndTime ?? this.targetEndTime),
        stateBeforePause: clearStateBeforePause
            ? null
            : (stateBeforePause ?? this.stateBeforePause),
        isAlarmRinging: isAlarmRinging ?? this.isAlarmRinging,
        todaySessions: todaySessions ?? this.todaySessions,
        allSessions: allSessions ?? this.allSessions,
        settings: settings ?? this.settings,
      );

  int get currentDuration {
    switch (state) {
      case PomodoroState.working:
        return settings.workDuration * 60;
      case PomodoroState.shortBreak:
        return settings.shortBreakDuration * 60;
      case PomodoroState.longBreak:
        return settings.longBreakDuration * 60;
      default:
        return settings.workDuration * 60;
    }
  }

  bool get isActive =>
      state == PomodoroState.working ||
      state == PomodoroState.shortBreak ||
      state == PomodoroState.longBreak ||
      state == PomodoroState.paused;

  bool get isBreak =>
      state == PomodoroState.shortBreak || state == PomodoroState.longBreak;

  String get stateLabel {
    if (isAlarmRinging) return 'Time\'s Up!';
    switch (state) {
      case PomodoroState.idle:
        return 'Ready to Start';
      case PomodoroState.working:
        return 'Focus Time';
      case PomodoroState.shortBreak:
        return 'Short Break';
      case PomodoroState.longBreak:
        return 'Long Break';
      case PomodoroState.paused:
        return 'Paused';
    }
  }

  Color get stateColor {
    if (isAlarmRinging) return const Color(0xFFFF4444);
    switch (state) {
      case PomodoroState.idle:
        return const Color(0xFF7B6EF6);
      case PomodoroState.working:
        return const Color(0xFFFF6B6B);
      case PomodoroState.shortBreak:
        return const Color(0xFF4ECDC4); // Teal/Cyan - short break
      case PomodoroState.longBreak:
        return const Color(0xFFFFB74D); // Orange/Amber - long break
      case PomodoroState.paused:
        return const Color(0xFFFFA502);
    }
  }

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get todayWorkSessionsCount => todaySessions
      .where((s) => s.type == PomodoroSessionType.work && s.completed)
      .length;

  int get todayTotalMinutes => todaySessions
      .where((s) => s.completed)
      .fold(0, (sum, s) => sum + s.durationMinutes);
}
