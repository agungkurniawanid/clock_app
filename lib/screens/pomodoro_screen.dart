import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_providers.dart';
import '../models/pomodoro_model.dart';
import '../services/audio_service.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pomodoroState = ref.watch(pomodoroProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildTimerCircle(context, isDark, pomodoroState),
                    const SizedBox(height: 40),
                    _buildControls(context, isDark, pomodoroState),
                    const SizedBox(height: 30),
                    _buildSessionInfo(context, isDark, pomodoroState),
                    const SizedBox(height: 30),
                    _buildTodayStats(context, isDark, pomodoroState),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pomodoro Timer',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Stay focused and productive',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showSettingsDialog(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCircle(
      BuildContext context, bool isDark, PomodoroTimerState state) {
    final progress = state.currentDuration > 0
        ? state.remainingSeconds / state.currentDuration
        : 0.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        // Pulse saat timer aktif (bukan pause) ATAU saat alarm berbunyi
        final shouldPulse =
            (state.isActive && state.state != PomodoroState.paused) ||
                state.isAlarmRinging;
        final pulseValue = shouldPulse ? _pulseController.value * 0.05 : 0.0;

        return Container(
          width: 300 + (pulseValue * 20),
          height: 300 + (pulseValue * 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: state.stateColor.withOpacity(0.3),
                blurRadius: 30 + (pulseValue * 20),
                spreadRadius: 5 + (pulseValue * 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(300, 300),
                painter: _CircularProgressPainter(
                  progress: progress,
                  color: state.stateColor,
                  isDark: isDark,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.formattedTime,
                    style: GoogleFonts.inter(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.stateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: state.stateColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(
      BuildContext context, bool isDark, PomodoroTimerState state) {
    // Prioritas: alarm berbunyi → tampilkan tombol stop alarm + tombol sesi berikutnya
    if (state.isAlarmRinging) {
      return _buildAlarmRingingControls(context, isDark, state);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.isActive) ...[
            _buildControlButton(
              context,
              isDark,
              icon: state.state == PomodoroState.paused
                  ? Icons.play_arrow
                  : Icons.pause,
              label: state.state == PomodoroState.paused ? 'Resume' : 'Pause',
              color: const Color(0xFFFFA502), // Orange - untuk pause/resume
              onTap: () {
                if (state.state == PomodoroState.paused) {
                  ref.read(pomodoroProvider.notifier).resume();
                } else {
                  ref.read(pomodoroProvider.notifier).pause();
                }
              },
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              context,
              isDark,
              icon: Icons.stop,
              label: 'Stop',
              color: const Color(0xFFE53935), // Merah - untuk stop/berhenti
              onTap: () => _showStopConfirmation(context),
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              context,
              isDark,
              icon: Icons.skip_next,
              label: 'Skip',
              color: const Color(0xFF7B6EF6), // Ungu - untuk skip/lewati
              onTap: () => ref.read(pomodoroProvider.notifier).skip(),
            ),
          ] else ...[
            _buildControlButton(
              context,
              isDark,
              icon: Icons.play_arrow,
              label: 'Start Work',
              color: const Color(0xFF4CAF50), // Hijau - untuk memulai kerja
              onTap: () => ref.read(pomodoroProvider.notifier).startWork(),
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              context,
              isDark,
              icon: Icons.coffee,
              label: 'Short Break',
              color: const Color(0xFF4ECDC4), // Teal/Cyan - untuk break pendek
              onTap: () =>
                  ref.read(pomodoroProvider.notifier).startShortBreak(),
            ),
            const SizedBox(width: 12),
            _buildControlButton(
              context,
              isDark,
              icon: Icons.bed,
              label: 'Long Break',
              color:
                  const Color(0xFFFFB74D), // Orange/Amber - untuk break panjang
              onTap: () => ref.read(pomodoroProvider.notifier).startLongBreak(),
            ),
          ],
        ],
      ),
    );
  }

  /// Tampilan kontrol saat alarm berbunyi setelah sesi selesai.
  /// Menampilkan tombol Stop Alarm yang besar dan tombol-tombol sesi berikutnya.
  Widget _buildAlarmRingingControls(
      BuildContext context, bool isDark, PomodoroTimerState state) {
    return Column(
      children: [
        // Tombol Stop Alarm yang besar dan mencolok
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + _pulseController.value * 0.03;
            return Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: () => ref.read(pomodoroProvider.notifier).stopAlarm(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4444), Color(0xFFFF6B6B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4444)
                            .withOpacity(0.4 + _pulseController.value * 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alarm_off,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Stop Alarm',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Tombol mulai sesi berikutnya
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                context,
                isDark,
                icon: Icons.play_arrow,
                label: 'Start Work',
                color: const Color(0xFF4CAF50),
                onTap: () => ref.read(pomodoroProvider.notifier).startWork(),
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                context,
                isDark,
                icon: Icons.coffee,
                label: 'Short Break',
                color: const Color(0xFF4ECDC4),
                onTap: () =>
                    ref.read(pomodoroProvider.notifier).startShortBreak(),
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                context,
                isDark,
                icon: Icons.bed,
                label: 'Long Break',
                color: const Color(0xFFFFB74D),
                onTap: () =>
                    ref.read(pomodoroProvider.notifier).startLongBreak(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfo(
      BuildContext context, bool isDark, PomodoroTimerState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              context,
              isDark,
              icon: Icons.work_outline,
              label: 'Work Duration',
              value: '${state.settings.workDuration} min',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.1),
          ),
          Expanded(
            child: _buildInfoItem(
              context,
              isDark,
              icon: Icons.coffee_outlined,
              label: 'Break Duration',
              value: '${state.settings.shortBreakDuration} min',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStats(
      BuildContext context, bool isDark, PomodoroTimerState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Progress',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  isDark,
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: '${state.completedWorkSessions}',
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  isDark,
                  icon: Icons.access_time,
                  label: 'Minutes',
                  value: '${state.todayTotalMinutes}',
                  color: const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStopConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Timer?'),
        content:
            const Text('Are you sure you want to stop the current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(pomodoroProvider.notifier).reset();
              Navigator.pop(context);
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final currentSettings = ref.read(pomodoroProvider).settings;

    int workDuration = currentSettings.workDuration;
    int shortBreak = currentSettings.shortBreakDuration;
    int longBreak = currentSettings.longBreakDuration;
    int sessionsBeforeLong = currentSettings.sessionsBeforeLongBreak;
    bool autoStartBreaks = currentSettings.autoStartBreaks;
    bool autoStartPomodoros = currentSettings.autoStartPomodoros;
    String alarmSound = currentSettings.alarmSound;
    double alarmVolume = currentSettings.alarmVolume;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Pomodoro Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingItem(
                    'Work Duration',
                    '$workDuration minutes',
                    () async {
                      final result = await _showNumberPicker(
                        context,
                        'Work Duration (minutes)',
                        workDuration,
                        1,
                        60,
                      );
                      if (result != null) {
                        setState(() => workDuration = result);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    'Short Break',
                    '$shortBreak minutes',
                    () async {
                      final result = await _showNumberPicker(
                        context,
                        'Short Break (minutes)',
                        shortBreak,
                        1,
                        30,
                      );
                      if (result != null) {
                        setState(() => shortBreak = result);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    'Long Break',
                    '$longBreak minutes',
                    () async {
                      final result = await _showNumberPicker(
                        context,
                        'Long Break (minutes)',
                        longBreak,
                        1,
                        60,
                      );
                      if (result != null) {
                        setState(() => longBreak = result);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    'Sessions Before Long Break',
                    '$sessionsBeforeLong sessions',
                    () async {
                      final result = await _showNumberPicker(
                        context,
                        'Sessions Before Long Break',
                        sessionsBeforeLong,
                        2,
                        10,
                      );
                      if (result != null) {
                        setState(() => sessionsBeforeLong = result);
                      }
                    },
                  ),
                  const Divider(height: 24),
                  Text(
                    'Alarm Sound',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    'Sound',
                    AudioService.displayName(alarmSound),
                    () async {
                      await _showMusicPickerSheet(context, (newSound) {
                        if (newSound != null) {
                          setState(() => alarmSound = newSound);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Volume: ${alarmVolume.round()}%',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  Slider(
                    value: alarmVolume,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${alarmVolume.round()}%',
                    onChanged: (val) => setState(() => alarmVolume = val),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title: Text(
                      'Auto-start Breaks',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    value: autoStartBreaks,
                    onChanged: (val) => setState(() => autoStartBreaks = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Auto-start Pomodoros',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    value: autoStartPomodoros,
                    onChanged: (val) =>
                        setState(() => autoStartPomodoros = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newSettings = PomodoroSettings(
                  workDuration: workDuration,
                  shortBreakDuration: shortBreak,
                  longBreakDuration: longBreak,
                  sessionsBeforeLongBreak: sessionsBeforeLong,
                  autoStartBreaks: autoStartBreaks,
                  autoStartPomodoros: autoStartPomodoros,
                  alarmSound: alarmSound,
                  alarmVolume: alarmVolume,
                );
                ref.read(pomodoroProvider.notifier).updateSettings(newSettings);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _showNumberPicker(
    BuildContext context,
    String title,
    int initialValue,
    int min,
    int max,
  ) async {
    int selectedValue = initialValue;

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter()),
        content: SizedBox(
          height: 200,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 50,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              selectedValue = min + index;
            },
            controller: FixedExtentScrollController(
              initialItem: initialValue - min,
            ),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final value = min + index;
                if (value > max) return null;
                return Center(
                  child: Text(
                    '$value',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selectedValue),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMusicFile(void Function(String?) setter) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final pickedPath = result.files.first.path;
      setter(pickedPath);
    }
  }

  Future<void> _showMusicPickerSheet(
      BuildContext context, void Function(String?) setter) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get custom files from user's custom music files
    final customFiles = <String>[];
    final tasks = ref.read(taskListProvider);
    final seen = <String>{};

    // Collect custom files from tasks
    for (final t in tasks) {
      for (final f in [t.musicFile, t.dueMusicFile]) {
        if (f != null && !AudioService.isAsset(f) && seen.add(f)) {
          customFiles.add(f);
        }
      }
    }

    String? previewingFile;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select Alarm Sound',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    // Default alarm sounds
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                        'Default Alarm Sounds',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7B6EF6),
                        ),
                      ),
                    ),
                    ...AudioService.defaultSounds.map((f) {
                      final isPreviewing = previewingFile == f;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              const Color(0xFF7B6EF6).withOpacity(0.1),
                          child: Icon(
                            isPreviewing
                                ? Icons.stop_circle_outlined
                                : Icons.music_note_rounded,
                            size: 20,
                            color: const Color(0xFF7B6EF6),
                          ),
                        ),
                        title: Text(
                          AudioService.displayName(f),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        subtitle: Text('Built-in alarm',
                            style: GoogleFonts.inter(fontSize: 12)),
                        trailing: IconButton(
                          icon: Icon(
                              isPreviewing ? Icons.stop : Icons.play_arrow),
                          onPressed: () async {
                            if (isPreviewing) {
                              await AudioService.instance.stop();
                              setLocalState(() => previewingFile = null);
                            } else {
                              await AudioService.instance.previewAsset(f);
                              setLocalState(() => previewingFile = f);
                            }
                          },
                        ),
                        onTap: () {
                          setter(f);
                          Navigator.pop(ctx);
                        },
                      );
                    }),

                    // Custom files section
                    if (customFiles.isNotEmpty) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Text(
                          'Custom Files',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4ECDC4),
                          ),
                        ),
                      ),
                      ...customFiles.map((f) {
                        final isPreviewing = previewingFile == f;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                const Color(0xFF4ECDC4).withOpacity(0.1),
                            child: Icon(
                              isPreviewing
                                  ? Icons.stop_circle_outlined
                                  : Icons.folder_rounded,
                              size: 20,
                              color: const Color(0xFF4ECDC4),
                            ),
                          ),
                          title: Text(
                            AudioService.displayName(f),
                            style: GoogleFonts.inter(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Custom file',
                              style: GoogleFonts.inter(fontSize: 12)),
                          trailing: IconButton(
                            icon: Icon(
                                isPreviewing ? Icons.stop : Icons.play_arrow),
                            onPressed: () async {
                              if (isPreviewing) {
                                await AudioService.instance.stop();
                                setLocalState(() => previewingFile = null);
                              } else {
                                await AudioService.instance.previewAsset(f);
                                setLocalState(() => previewingFile = f);
                              }
                            },
                          ),
                          onTap: () {
                            setter(f);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],

                    // Browse files button
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickMusicFile(setter);
                        },
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse files from storage'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: const Color(0xFF7B6EF6).withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Stop any preview when sheet closes
    await AudioService.instance.stop();
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black87).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawCircle(center, radius - 6, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
