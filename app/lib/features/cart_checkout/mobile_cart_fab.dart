import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/pos_providers.dart';
import 'retail_cart_tray.dart';

/// Mobile cart button: badge count + shake + confetti on add-to-cart.
///
/// Uses a fixed-size [FloatingActionButton] (not extended) so the Scaffold
/// doesn’t resize/animate a full-width band under the button on every add.
class MobileCartFab extends ConsumerStatefulWidget {
  const MobileCartFab({super.key});

  @override
  ConsumerState<MobileCartFab> createState() => _MobileCartFabState();
}

class _MobileCartFabState extends ConsumerState<MobileCartFab>
    with TickerProviderStateMixin {
  late final AnimationController _shake;
  late final AnimationController _confetti;
  late final AnimationController _badgePop;
  final _rng = math.Random();
  late List<_ConfettiBit> _bits;

  @override
  void initState() {
    super.initState();
    _bits = const [];
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _badgePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    _confetti.dispose();
    _badgePop.dispose();
    super.dispose();
  }

  void _celebrate() {
    _bits = List.generate(18, (_) {
      final angle = -math.pi * 0.15 - _rng.nextDouble() * math.pi * 0.7;
      final speed = 70 + _rng.nextDouble() * 110;
      return _ConfettiBit(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed - 30,
        spin: (_rng.nextDouble() - 0.5) * 8,
        color: [
          AppColors.accent,
          AppColors.brandYellow,
          AppColors.brandOrange,
          AppColors.accentDeep,
          const Color(0xFFE53935),
          const Color(0xFF43A047),
        ][_rng.nextInt(6)],
        size: 4 + _rng.nextDouble() * 4,
        shape: _rng.nextBool() ? _ConfettiShape.rect : _ConfettiShape.circle,
      );
    });
    _shake.forward(from: 0);
    _confetti.forward(from: 0);
    _badgePop.forward(from: 0);
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return SizedBox(
          height: maxHeight,
          child: const RetailCartTray(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(
      cartProvider.select(
        (cart) => cart.fold<int>(0, (s, l) => s + l.quantity),
      ),
    );

    ref.listen<String?>(cartAddPulseProvider, (prev, next) {
      if (next != null && next != prev) _celebrate();
    });

    final shakeT = CurvedAnimation(parent: _shake, curve: Curves.easeOut);
    final badgeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1), weight: 60),
    ]).animate(CurvedAnimation(parent: _badgePop, curve: Curves.easeOutBack));

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) {
                  if (!_confetti.isAnimating && _confetti.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confetti.value,
                      bits: _bits,
                    ),
                  );
                },
              ),
            ),
          ),
          AnimatedBuilder(
            animation: shakeT,
            builder: (context, child) {
              final wiggle = math.sin(shakeT.value * math.pi * 6) *
                  (1 - shakeT.value) *
                  0.18;
              return Transform.rotate(
                angle: wiggle,
                child: Transform.translate(
                  offset: Offset(
                    math.sin(shakeT.value * math.pi * 5) * (1 - shakeT.value) * 6,
                    0,
                  ),
                  child: child,
                ),
              );
            },
            child: FloatingActionButton(
              heroTag: null,
              onPressed: _openCart,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              elevation: 3,
              highlightElevation: 3,
              tooltip: count > 0 ? 'Cart ($count)' : 'Cart',
              child: const Icon(Icons.shopping_bag_rounded),
            ),
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: ScaleTransition(
                scale: badgeScale,
                child: _CartBadge(count: count),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

enum _ConfettiShape { rect, circle }

class _ConfettiBit {
  const _ConfettiBit({
    required this.dx,
    required this.dy,
    required this.spin,
    required this.color,
    required this.size,
    required this.shape,
  });

  final double dx;
  final double dy;
  final double spin;
  final Color color;
  final double size;
  final _ConfettiShape shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.bits});

  final double progress;
  final List<_ConfettiBit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.5, size.height * 0.55);
    final g = 420.0;
    for (final bit in bits) {
      final t = progress;
      final x = origin.dx + bit.dx * t;
      final y = origin.dy + bit.dy * t + 0.5 * g * t * t;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = bit.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(bit.spin * t);
      if (bit.shape == _ConfettiShape.circle) {
        canvas.drawCircle(Offset.zero, bit.size * 0.55, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: bit.size, height: bit.size * 0.55),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
