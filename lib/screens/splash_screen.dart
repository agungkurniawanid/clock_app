// Photos sourced from Unsplash (unsplash.com) — free to use under the Unsplash License.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _glowController;
  late final AnimationController _progressController;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    _textController.forward();
    _progressController.forward();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      ref.read(splashDoneProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    _progressController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash always has a deep dark background — force white system icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF05000F),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background image (aurora / night sky from Unsplash, Unsplash License) ──
            FadeTransition(
              opacity:
                  CurvedAnimation(parent: _bgController, curve: Curves.easeIn),
              child: Image.network(
                'https://images.unsplash.com/photo-1531366936337-7c912a4589a7'
                '?auto=format&fit=crop&w=800&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF05000F),
                        Color(0xFF1A0533),
                        Color(0xFF0D1B4D),
                        Color(0xFF05000F),
                      ],
                      stops: [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Gradient overlay (darkens bottom for readability) ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.75, 1.0],
                  colors: [
                    const Color(0xFF05000F).withValues(alpha: 0.45),
                    const Color(0xFF0D0221).withValues(alpha: 0.60),
                    const Color(0xFF0D0221).withValues(alpha: 0.88),
                    const Color(0xFF0D0221).withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),

            // ── Content ──
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),

                  // Animated rings + logo
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_logoController, _glowController, _ringController]),
                    builder: (context, _) {
                      final logoFade = Tween<double>(begin: 0, end: 1).evaluate(
                        CurvedAnimation(
                            parent: _logoController,
                            curve: const Interval(0, 0.45)),
                      );
                      final logoScale = Tween<double>(begin: 0.25, end: 1.0)
                          .evaluate(CurvedAnimation(
                              parent: _logoController,
                              curve: Curves.elasticOut));
                      final glowRadius =
                          Tween<double>(begin: 18, end: 48).evaluate(
                        CurvedAnimation(
                            parent: _glowController, curve: Curves.easeInOut),
                      );
                      final ringProgress = _ringController.value;

                      return Opacity(
                        opacity: logoFade,
                        child: Transform.scale(
                          scale: logoScale,
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer animated ring
                                Opacity(
                                  opacity: (1 - ringProgress).clamp(0, 1),
                                  child: Transform.scale(
                                    scale: 0.62 + ringProgress * 0.55,
                                    child: Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF7C3AED)
                                              .withValues(alpha: 0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Middle ring
                                Opacity(
                                  opacity:
                                      ((0.5 - (ringProgress - 0.5).abs()) * 2)
                                          .clamp(0, 1),
                                  child: Transform.scale(
                                    scale: 0.62 +
                                        ((ringProgress + 0.5) % 1.0) * 0.55,
                                    child: Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF4F46E5)
                                              .withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Logo circle
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF9B5CF6),
                                        Color(0xFF4F46E5),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.65),
                                        blurRadius: glowRadius,
                                        spreadRadius: glowRadius / 6,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5)
                                            .withValues(alpha: 0.35),
                                        blurRadius: glowRadius * 1.8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Image.asset(
                                      'assets/icon-launcher-2.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, _) {
                      final opacity = Tween<double>(begin: 0, end: 1).evaluate(
                        CurvedAnimation(
                            parent: _textController, curve: Curves.easeIn),
                      );
                      final slide = Tween<double>(begin: 28, end: 0).evaluate(
                        CurvedAnimation(
                            parent: _textController, curve: Curves.easeOut),
                      );
                      return Transform.translate(
                        offset: Offset(0, slide),
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            children: [
                              Text(
                                'SmartAlarm',
                                style: GoogleFonts.nunito(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Task Scheduler & Smart Clock',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 4),

                  // Progress bar + label
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      final labelOpacity = Tween<double>(begin: 0, end: 1)
                          .evaluate(CurvedAnimation(
                              parent: _textController, curve: Curves.easeIn));
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: 44, left: 56, right: 56),
                        child: Column(
                          children: [
                            Text(
                              'Loading your experience...',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: Colors.white
                                    .withValues(alpha: 0.35 * labelOpacity),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progressController.value,
                                minHeight: 2.5,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ), // Stack
      ), // Scaffold
    ); // AnnotatedRegion
  }
}
