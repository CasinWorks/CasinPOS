import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/brand_mark.dart';

/// Duck-shopping splash: waddle + random puns while the app boots.
class FluidInkIntro extends StatefulWidget {
  const FluidInkIntro({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 4200),
  });

  final VoidCallback onComplete;
  final Duration duration;

  @override
  State<FluidInkIntro> createState() => _FluidInkIntroState();
}

class _FluidInkIntroState extends State<FluidInkIntro>
    with TickerProviderStateMixin {
  late final AnimationController _progress;
  late final AnimationController _waddle;
  late final math.Random _rng;
  late String _pun;
  late List<String> _remaining;
  Timer? _punTimer;

  static const _puns = [
    'Duck is shopping… putting it on the bill',
    'Waddling to checkout… please hold still',
    'Filling the bag with quackers',
    'Just a quick quack-action…',
    'Scanning aisles for bargains (and bread)',
    'Counting coins with webbed feet',
    'Not egg-stravagant… just loading',
    'Fetching your POS — no, wait, I’m a duck',
    'Organizing the flock (and the SKUs)',
    'Hopping brands into the cart',
    'Duck, duck… ring up!',
    'Making change without losing a feather',
    'Bread in bag > bugs in build',
    'This bill is totally quackers',
    'Aisle be right with you…',
    'Checking out like a BOSS (mallard)',
    'Rolling into retail with a rubber soul',
    'Receipt paper? More like duck tape',
    'Beak peek: almost ready…',
    'Loading faster than a Sunday market run',
  ];

  @override
  void initState() {
    super.initState();
    _rng = math.Random();
    _remaining = List<String>.from(_puns)..shuffle(_rng);
    _pun = _remaining.removeLast();

    _waddle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _progress = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();

    _punTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(_nextPun);
    });
  }

  void _nextPun() {
    if (_remaining.isEmpty) {
      _remaining = List<String>.from(_puns)..shuffle(_rng);
      _remaining.removeWhere((p) => p == _pun);
    }
    if (_remaining.isEmpty) return;
    _pun = _remaining.removeAt(_rng.nextInt(_remaining.length));
  }

  @override
  void dispose() {
    _punTimer?.cancel();
    _progress.dispose();
    _waddle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkIntroBg,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF5),
              Color(0xFFFFF3C4),
              Color(0xFFFFE082),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _waddle,
              builder: (context, _) => CustomPaint(painter: _SoftOrbPainter(_waddle.value)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_waddle, _progress]),
                      builder: (context, _) {
                        final bob = math.sin(_waddle.value * math.pi) * 10;
                        final tilt = (_waddle.value - 0.5) * 0.18;
                        final scale = 0.96 + (_waddle.value * 0.08);
                        final fadeIn = (_progress.value / 0.12).clamp(0.0, 1.0);
                        final fadeOut = _progress.value > 0.88
                            ? (1 - (_progress.value - 0.88) / 0.12).clamp(0.0, 1.0)
                            : 1.0;

                        return Opacity(
                          opacity: fadeIn * fadeOut,
                          child: Transform.translate(
                            offset: Offset(0, bob),
                            child: Transform.rotate(
                              angle: tilt,
                              child: Transform.scale(
                                scale: scale,
                                child: Column(
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accent.withValues(alpha: 0.35),
                                            blurRadius: 36,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        BrandAssets.duck,
                                        height: 168,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: (_, error, stack) =>
                                            const BrandLogo(size: 140),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(5, (i) {
                                        final active =
                                            ((_waddle.value * 5) + i) % 5 < 2.2;
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: AppColors.accentDeep.withValues(
                                              alpha: active ? 0.85 : 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'CASIN POS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'POINT OF SALE  ·  INVENTORY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 48,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _pun,
                          key: ValueKey(_pun),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 220,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.65),
                              color: AppColors.accentDeep,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Powered by CASINWORKS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: FilledButton.tonal(
                onPressed: widget.onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink.withValues(alpha: 0.88),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftOrbPainter extends CustomPainter {
  _SoftOrbPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      (Offset(size.width * 0.18, size.height * 0.22), 70.0, AppColors.accent),
      (Offset(size.width * 0.82, size.height * 0.28), 90.0, AppColors.brandOrange),
      (Offset(size.width * 0.7, size.height * 0.75), 80.0, AppColors.brandYellow),
      (Offset(size.width * 0.22, size.height * 0.72), 60.0, AppColors.accentDeep),
    ];
    for (var i = 0; i < orbs.length; i++) {
      final (c, r, color) = orbs[i];
      final drift = math.sin((t + i * 0.2) * math.pi) * 12;
      final paint = Paint()..color = color.withValues(alpha: 0.12 + (i % 2) * 0.04);
      canvas.drawCircle(c.translate(0, drift), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftOrbPainter oldDelegate) => oldDelegate.t != t;
}
