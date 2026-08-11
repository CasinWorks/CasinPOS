import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/pos_providers.dart';
import 'retail_cart_tray.dart';

/// Mobile cart control: solid gold button (not M3 FAB — FAB state overlays
/// flash gray on every add). Badge + light shake on add-to-cart.
class MobileCartFab extends ConsumerStatefulWidget {
  const MobileCartFab({super.key});

  @override
  ConsumerState<MobileCartFab> createState() => _MobileCartFabState();
}

class _MobileCartFabState extends ConsumerState<MobileCartFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _celebrate() {
    _shake.forward(from: 0);
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

    return SizedBox(
      width: 64,
      height: 64,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_shake.value);
          final wiggle = math.sin(t * math.pi * 5) * (1 - t) * 0.14;
          return Transform.rotate(
            angle: wiggle,
            child: Transform.translate(
              offset: Offset(math.sin(t * math.pi * 4) * (1 - t) * 5, 0),
              child: child,
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Material(
              color: AppColors.accent,
              elevation: 3,
              shadowColor: Colors.black26,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _openCart,
                splashColor: AppColors.accentDeep.withValues(alpha: 0.28),
                highlightColor: Colors.transparent,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: AppColors.ink,
                    size: 26,
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: _CartBadge(count: count),
              ),
          ],
        ),
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
