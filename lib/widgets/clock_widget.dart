import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClockWidget extends StatefulWidget {
  final bool showDate;

  const ClockWidget({super.key, this.showDate = true});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late DateTime _now;
  late Timer _timer;

  static const _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  static const _months = [
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
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textPrimary = Theme.of(context).textTheme.displayLarge?.color;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color;
    final h = _pad(_now.hour);
    final m = _pad(_now.minute);
    final s = _pad(_now.second);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$h:$m',
              style: GoogleFonts.nunito(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                ':$s',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: primary,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
        if (widget.showDate) ...[
          const SizedBox(height: 4),
          Text(
            '${_weekDays[_now.weekday - 1]}, ${_months[_now.month - 1]} ${_now.day}, ${_now.year}',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
