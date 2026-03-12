import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_providers.dart';
import '../models/pomodoro_model.dart';
import '../services/audio_service.dart';
import '../utils/dialog_utils.dart';

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
    showScaleDialog(
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.92,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.timer_outlined,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pomodoro Settings',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Customize your focus sessions',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Scrollable Content ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timer Duration section
                            _settingsSectionLabel(ctx, isDark, 'Timer Duration',
                                Icons.hourglass_empty_rounded),
                            const SizedBox(height: 10),
                            _buildStepperRow(
                              ctx,
                              isDark,
                              'Work Session',
                              workDuration,
                              1,
                              60,
                              'min',
                              onDecrement: () {
                                if (workDuration > 1)
                                  setDialogState(() => workDuration--);
                              },
                              onIncrement: () {
                                if (workDuration < 60)
                                  setDialogState(() => workDuration++);
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildStepperRow(
                              ctx,
                              isDark,
                              'Short Break',
                              shortBreak,
                              1,
                              30,
                              'min',
                              onDecrement: () {
                                if (shortBreak > 1)
                                  setDialogState(() => shortBreak--);
                              },
                              onIncrement: () {
                                if (shortBreak < 30)
                                  setDialogState(() => shortBreak++);
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildStepperRow(
                              ctx,
                              isDark,
                              'Long Break',
                              longBreak,
                              1,
                              60,
                              'min',
                              onDecrement: () {
                                if (longBreak > 1)
                                  setDialogState(() => longBreak--);
                              },
                              onIncrement: () {
                                if (longBreak < 60)
                                  setDialogState(() => longBreak++);
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildStepperRow(
                              ctx,
                              isDark,
                              'Sessions / Long Break',
                              sessionsBeforeLong,
                              2,
                              10,
                              'x',
                              onDecrement: () {
                                if (sessionsBeforeLong > 2)
                                  setDialogState(() => sessionsBeforeLong--);
                              },
                              onIncrement: () {
                                if (sessionsBeforeLong < 10)
                                  setDialogState(() => sessionsBeforeLong++);
                              },
                            ),
                            const SizedBox(height: 20),
                            _settingsDivider(isDark),
                            const SizedBox(height: 16),

                            // Auto Start section
                            _settingsSectionLabel(ctx, isDark, 'Auto Start',
                                Icons.autorenew_rounded),
                            const SizedBox(height: 10),
                            _buildModernSwitch(
                              ctx,
                              isDark,
                              'Auto-start Breaks',
                              'Automatically start break after work',
                              autoStartBreaks,
                              (v) => setDialogState(() => autoStartBreaks = v),
                            ),
                            const SizedBox(height: 8),
                            _buildModernSwitch(
                              ctx,
                              isDark,
                              'Auto-start Pomodoros',
                              'Automatically start work after break',
                              autoStartPomodoros,
                              (v) =>
                                  setDialogState(() => autoStartPomodoros = v),
                            ),
                            const SizedBox(height: 20),
                            _settingsDivider(isDark),
                            const SizedBox(height: 16),

                            // Alarm Sound section
                            _settingsSectionLabel(ctx, isDark, 'Alarm Sound',
                                Icons.music_note_outlined),
                            const SizedBox(height: 10),
                            _buildSoundSelector(ctx, isDark, alarmSound,
                                () async {
                              await _showMusicPickerSheet(ctx, (newSound) {
                                if (newSound != null)
                                  setDialogState(() => alarmSound = newSound);
                              });
                            }),
                            const SizedBox(height: 14),
                            // Volume slider row
                            Row(
                              children: [
                                Icon(Icons.volume_down_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black38),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 16),
                                      activeTrackColor: const Color(0xFFFF6B6B),
                                      inactiveTrackColor: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                      thumbColor: const Color(0xFFFF6B6B),
                                      overlayColor: const Color(0xFFFF6B6B)
                                          .withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: alarmVolume,
                                      min: 0,
                                      max: 100,
                                      divisions: 100,
                                      onChanged: (val) => setDialogState(
                                          () => alarmVolume = val),
                                    ),
                                  ),
                                ),
                                Icon(Icons.volume_up_rounded,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black38),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    '${alarmVolume.round()}%',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer Buttons ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: isDark
                                    ? Colors.white.withOpacity(0.07)
                                    : Colors.grey.shade100,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                ref
                                    .read(pomodoroProvider.notifier)
                                    .updateSettings(PomodoroSettings(
                                      workDuration: workDuration,
                                      shortBreakDuration: shortBreak,
                                      longBreakDuration: longBreak,
                                      sessionsBeforeLongBreak:
                                          sessionsBeforeLong,
                                      autoStartBreaks: autoStartBreaks,
                                      autoStartPomodoros: autoStartPomodoros,
                                      alarmSound: alarmSound,
                                      alarmVolume: alarmVolume,
                                    ));
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFFF8E53),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B6B)
                                          .withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'Save Settings',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingsSectionLabel(
      BuildContext context, bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFFFF6B6B)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildStepperRow(
    BuildContext context,
    bool isDark,
    String label,
    int value,
    int min,
    int max,
    String unit, {
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
              ),
            ),
          ),
          GestureDetector(
            onTap: value > min ? onDecrement : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: value > min
                    ? const Color(0xFFFF6B6B).withOpacity(0.12)
                    : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.remove,
                size: 18,
                color: value > min
                    ? const Color(0xFFFF6B6B)
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  unit,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: value < max ? onIncrement : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: value < max
                    ? const Color(0xFFFF6B6B).withOpacity(0.12)
                    : (isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: value < max
                    ? const Color(0xFFFF6B6B)
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSwitch(
    BuildContext context,
    bool isDark,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withOpacity(0.85)
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFFFF6B6B),
              inactiveTrackColor: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.grey.shade300,
              inactiveThumbColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundSelector(
    BuildContext context,
    bool isDark,
    String currentSound,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Color(0xFFFF6B6B), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sound',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  Text(
                    AudioService.displayName(currentSound),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withOpacity(0.85)
                          : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsDivider(bool isDark) {
    return Divider(
      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
      thickness: 1,
      height: 1,
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

    await showScaleBottomSheet(
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
