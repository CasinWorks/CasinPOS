import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/brand_mark.dart';

/// Port of the AI Studio Fluid Ink intro (ink swirl → logo → dissolve).
class FluidInkIntro extends StatefulWidget {
  const FluidInkIntro({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 3800),
  });

  final VoidCallback onComplete;
  final Duration duration;

  @override
  State<FluidInkIntro> createState() => _FluidInkIntroState();
}

class _FluidInkIntroState extends State<FluidInkIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_InkParticle> _particles;
  final _rng = math.Random(42);

  static const _colors = [
    AppColors.accentDeep,
    AppColors.accent,
    AppColors.brandYellow,
    AppColors.brandOrange,
    AppColors.inkDeep,
  ];

  @override
  void initState() {
    super.initState();
    _particles = List.generate(140, (_) => _InkParticle.seed(_rng));
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkIntroBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _InkPainter(
                  progress: _controller.value,
                  particles: _particles,
                  colors: _colors,
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final p = _controller.value;
              final showLogo = p >= 0.47 && p < 0.92;
              final opacity = showLogo
                  ? (p < 0.55
                      ? ((p - 0.47) / 0.08).clamp(0.0, 1.0)
                      : p > 0.79
                          ? (1 - (p - 0.79) / 0.13).clamp(0.0, 1.0)
                          : 1.0)
                  : 0.0;
              return IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandLogo(size: 156, radius: 28, shadow: true),
                        const SizedBox(height: 16),
                        Text(
                          'POINT OF SALE  ·  INVENTORY',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 2.4,
                                color: AppColors.slate700,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Powered by CASINWORKS',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                letterSpacing: 0.6,
                                color: AppColors.slate500,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 24,
            right: 24,
            child: FilledButton.tonal(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate900.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
              ),
              child: const Text('Skip'),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: SizedBox(
                width: 192,
                height: 4,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _controller.value,
                        backgroundColor: AppColors.slate200,
                        color: AppColors.restaurant,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InkParticle {
  _InkParticle({
    required this.angle,
    required this.dist,
    required this.size,
    required this.colorIndex,
    required this.spin,
    required this.alpha,
  });

  factory _InkParticle.seed(math.Random rng) {
    return _InkParticle(
      angle: rng.nextDouble() * math.pi * 2,
      dist: rng.nextDouble() * 40,
      size: 10 + rng.nextDouble() * 34,
      colorIndex: rng.nextInt(5),
      spin: (rng.nextDouble() - 0.5) * 0.03,
      alpha: 0.2 + rng.nextDouble() * 0.55,
    );
  }

  final double angle;
  final double dist;
  final double size;
  final int colorIndex;
  final double spin;
  final double alpha;
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.progress,
    required this.particles,
    required this.colors,
  });

  final double progress;
  final List<_InkParticle> particles;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final elapsedMs = progress * 3800;

    final bg = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        math.max(size.width, size.height) * 0.7,
        [
          Colors.white.withValues(alpha: 0.95),
          const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        ],
      );
    canvas.drawRect(Offset.zero & size, bg);

    for (var i = 0; i < particles.length; i++) {
      final part = particles[i];
      late double x;
      late double y;
      late double particleSize;
      late double alpha;

      if (elapsedMs < 1800) {
        final t = elapsedMs / 1800;
        final swirl = part.angle + t * 2.2 + part.spin * elapsedMs;
        final radius = part.dist + 20 + t * (80 + (i % 7) * 18);
        x = cx + math.cos(swirl) * radius;
        y = cy + math.sin(swirl) * radius;
        particleSize = part.size * (1.1 - t * 0.15);
        alpha = part.alpha;
      } else if (elapsedMs < 3000) {
        final morph = ((elapsedMs - 1800) / 1200).clamp(0.0, 1.0);
        final logoAngle = (i / particles.length) * math.pi * 2;
        final logoRadius = 42.0 + (i % 3) * 6;
        final tx = cx + math.cos(logoAngle) * logoRadius;
        final ty = cy + math.sin(logoAngle) * logoRadius - 10;
        final swirl = part.angle + 2.2 + part.spin * 1800;
        final radius = part.dist + 100 + (i % 7) * 18;
        final sx = cx + math.cos(swirl) * radius;
        final sy = cy + math.sin(swirl) * radius;
        x = ui.lerpDouble(sx, tx, morph)!;
        y = ui.lerpDouble(sy, ty, morph)!;
        particleSize = ui.lerpDouble(part.size, 8, morph)!;
        alpha = part.alpha;
      } else {
        final dissolve = ((elapsedMs - 3000) / 800).clamp(0.0, 1.0);
        final logoAngle = (i / particles.length) * math.pi * 2;
        final logoRadius = 42.0 + (i % 3) * 6;
        x = cx + math.cos(logoAngle) * logoRadius;
        y = cy + math.sin(logoAngle) * logoRadius - 10;
        particleSize = 8 * (1 + dissolve * 1.2);
        alpha = part.alpha * (1 - dissolve);
      }

      final color = colors[part.colorIndex % colors.length];
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          particleSize,
          [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        );
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }

    if (elapsedMs >= 1800 && elapsedMs < 3200) {
      final morphP = ((elapsedMs - 1800) / 1200).clamp(0.0, 1.0);
      final goldAlpha = math.sin(morphP * math.pi) * 0.55;
      final aura = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          90,
          [
            AppColors.goldShimmer.withValues(alpha: goldAlpha * 0.45),
            AppColors.restaurant.withValues(alpha: goldAlpha * 0.2),
            Colors.transparent,
          ],
          [0.0, 0.55, 1.0],
        );
      canvas.drawCircle(Offset(cx, cy), 90, aura);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
