import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType { success, error, warning, info }

/// Overlay-based top-of-screen toast — does NOT overlap the bottom nav bar.
class AppToast {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // Dismiss any currently-visible toast immediately
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bgColor, borderColor, iconData, iconColor, textColor) =
        switch (widget.type) {
      ToastType.success => (
          isDark ? const Color(0xFF0D2E1A) : const Color(0xFFEBF7F0),
          const Color(0xFF38A169),
          Icons.check_circle_rounded,
          const Color(0xFF38A169),
          isDark ? const Color(0xFFD4F5E3) : const Color(0xFF1A4731),
        ),
      ToastType.error => (
          isDark ? const Color(0xFF2E0D0D) : const Color(0xFFFFF0F0),
          const Color(0xFFE53E3E),
          Icons.error_rounded,
          const Color(0xFFE53E3E),
          isDark ? const Color(0xFFFDD8D8) : const Color(0xFF6B1111),
        ),
      ToastType.warning => (
          isDark ? const Color(0xFF2E1D05) : const Color(0xFFFFF8E6),
          const Color(0xFFF5A623),
          Icons.warning_rounded,
          const Color(0xFFF5A623),
          isDark ? const Color(0xFFFFE4A8) : const Color(0xFF5A3A07),
        ),
      ToastType.info => (
          isDark ? const Color(0xFF091829) : const Color(0xFFEAF2FF),
          const Color(0xFF4A90E2),
          Icons.info_rounded,
          const Color(0xFF4A90E2),
          isDark ? const Color(0xFFBDD9FF) : const Color(0xFF1A3A6B),
        ),
    };

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: borderColor.withValues(alpha: 0.4), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(iconData, color: iconColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        widget.onAction?.call();
                        _dismiss();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: iconColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
