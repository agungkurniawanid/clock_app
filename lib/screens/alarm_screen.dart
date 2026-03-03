import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';

class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _stopAlarm() {
    ref.read(alarmActiveProvider.notifier).state = false;
    Navigator.pop(context);
  }

  void _stopAndComplete() {
    final taskId = ref.read(activeAlarmTaskIdProvider);
    if (taskId != null) {
      ref.read(taskListProvider.notifier).markComplete(taskId);
    }
    _stopAlarm();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider);
    final taskId = ref.watch(activeAlarmTaskIdProvider);
    final task =
        tasks.firstWhere((t) => t.id == taskId, orElse: () => tasks.first);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          final t = _bgCtrl.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                      const Color(0xFF1A0E3F), const Color(0xFF0E1A3F), t)!,
                  Color.lerp(
                      const Color(0xFF2D1B6E), const Color(0xFF1B2D6E), t)!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                ..._buildCircles(),
                // Content
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
                      // Music info
                      Text(
                        '🎵  ${task.musicFile ?? 'lofi_morning.mp3'} playing...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Date
                      Text(
                        _formatDate(task.date),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(flex: 1),
                      // Big clock
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: _buildClock(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Task name
                      Text(
                        task.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${task.description}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(flex: 1),
                      // Divider
                      Divider(color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      // Swipe slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1),
                          ),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 0,
                              thumbColor: Colors.white,
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              overlayColor: Colors.transparent,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 20),
                            ),
                            child: Slider(
                              value: _sliderValue,
                              onChanged: (v) =>
                                  setState(() => _sliderValue = v),
                              onChangeEnd: (v) {
                                if (v > 0.9) {
                                  _stopAlarm();
                                } else {
                                  setState(() => _sliderValue = 0);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Slide to dismiss alarm',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _stopAndComplete,
                                icon: const Icon(Icons.check_circle_rounded,
                                    size: 18),
                                label: const Text('Stop & Complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: statusCompleted,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _stopAlarm,
                                icon: const Icon(Icons.stop_rounded, size: 18),
                                label: const Text('Stop Only'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.4)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Snooze
                      GestureDetector(
                        onTap: () => _showSnoozeSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          decoration: BoxDecoration(
                            color: statusRisk.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: statusRisk.withValues(alpha: 0.4),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.snooze_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Snooze 15 min',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.settings_rounded,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 16),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCircles() {
    return [
      Positioned(
        top: -80,
        right: -80,
        child: AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => Container(
            width: 250 + _bgCtrl.value * 30,
            height: 250 + _bgCtrl.value * 30,
            decoration: BoxDecoration(
              color: darkPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -100,
        left: -60,
        child: AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => Container(
            width: 200 + (1 - _bgCtrl.value) * 40,
            height: 200 + (1 - _bgCtrl.value) * 40,
            decoration: BoxDecoration(
              color: darkSecondary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildClock(BuildContext context) {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$h:$m',
            style: GoogleFonts.nunito(
              fontSize: 68,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              ':$s',
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: darkPrimary,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnoozeSheet(BuildContext context) {
    final snoozeOptions = [5, 10, 15, 30];
    int selected = 15;

    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Custom Snooze Duration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: snoozeOptions.map((opt) {
                  final active = selected == opt;
                  return GestureDetector(
                    onTap: () => setS(() => selected = opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? darkPrimary : darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$opt min',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Confirm Snooze'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
