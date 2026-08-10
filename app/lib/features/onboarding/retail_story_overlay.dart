import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import 'story_mode.dart';
import 'tutorial_anchors.dart';

/// Interactive story: spotlight + pulse on the real control, coach card that doesn’t block the app.
class RetailStoryOverlay extends ConsumerStatefulWidget {
  const RetailStoryOverlay({super.key});

  @override
  ConsumerState<RetailStoryOverlay> createState() => _RetailStoryOverlayState();
}

class _RetailStoryOverlayState extends ConsumerState<RetailStoryOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _cardIn;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _cardIn = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _cardIn.dispose();
    super.dispose();
  }

  void _syncHole() {
    if (!mounted) return;
    final active = ref.read(storyModeActiveProvider);
    if (!active) {
      if (_hole != null) setState(() => _hole = null);
      return;
    }
    final storeName = ref.read(activeMembershipProvider)?.store.name ?? 'your store';
    final steps = retailStorySteps(storeName);
    final i = ref.read(storyStepIndexProvider).clamp(0, steps.length - 1);
    final highlight = steps[i].highlight;
    final next = highlight == null ? null : TutorialAnchors.rectOf(highlight, pad: 10);
    if (next != _hole) setState(() => _hole = next);
    // Keep tracking while targets move (nav/layout).
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted && ref.read(storyModeActiveProvider)) _syncHole();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(storyModeActiveProvider);
    if (!active) return const SizedBox.shrink();

    ref.listen(storyStepIndexProvider, (_, _) {
      _cardIn
        ..reset()
        ..forward();
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
    });
    ref.listen(retailTabProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
    });

    final storeName = ref.watch(activeMembershipProvider)?.store.name ?? 'your store';
    final steps = retailStorySteps(storeName);
    final index = ref.watch(storyStepIndexProvider).clamp(0, steps.length - 1);
    final step = steps[index];
    final products = ref.watch(posCatalogProvider).length;
    final cartCount = ref.watch(cartProvider).fold<int>(0, (s, l) => s + l.quantity);
    final orders = ref.watch(ordersProvider).length;

    ref.listen(posCatalogProvider, (prev, next) {
      if (!ref.read(storyModeActiveProvider)) return;
      final s = retailStorySteps(storeName)[ref.read(storyStepIndexProvider)];
      if (s.requireProduct && next.isNotEmpty) _goNext(steps, ref.read(storyStepIndexProvider));
    });
    ref.listen(cartProvider, (prev, next) {
      if (!ref.read(storyModeActiveProvider)) return;
      final s = retailStorySteps(storeName)[ref.read(storyStepIndexProvider)];
      if (s.requireCartItem && next.isNotEmpty) _goNext(steps, ref.read(storyStepIndexProvider));
    });
    ref.listen(ordersProvider, (prev, next) {
      if (!ref.read(storyModeActiveProvider)) return;
      final s = retailStorySteps(storeName)[ref.read(storyStepIndexProvider)];
      if (s.requireOrder && next.isNotEmpty) _goNext(steps, ref.read(storyStepIndexProvider));
    });

    final waitingOnAction = (step.requireProduct && products < 1) ||
        (step.requireCartItem && cartCount < 1) ||
        (step.requireOrder && orders < 1);

    return Stack(
      children: [
        // Glow only on the target — no full-screen dim.
        if (_hole != null)
          Positioned.fromRect(
            rect: _hole!,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.restaurant.withValues(alpha: 0.75 + t * 0.25),
                        width: 2.5 + t * 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.restaurant.withValues(alpha: 0.45 + t * 0.3),
                          blurRadius: 14 + t * 18,
                          spreadRadius: 1 + t * 3,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2 + t * 0.15),
                          blurRadius: 22 + t * 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: _cardIn, curve: Curves.easeOutCubic)),
                child: FadeTransition(
                  opacity: _cardIn,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1).animate(
                      CurvedAnimation(parent: _cardIn, curve: Curves.easeOutBack),
                    ),
                    child: _CoachCard(
                      index: index,
                      total: steps.length,
                      step: step,
                      waitingOnAction: waitingOnAction,
                      onSkip: () => skipRetailStory(ref),
                      onBack: index > 0
                          ? () => ref.read(storyStepIndexProvider.notifier).state = index - 1
                          : null,
                      onPrimary: () => _onPrimary(step, steps, index),
                      onFocusTarget: () {
                        if (step.targetTab != null) {
                          ref.read(retailTabProvider.notifier).state = step.targetTab!;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPrimary(StoryStep step, List<StoryStep> steps, int index) {
    if (step.id == StoryStepId.openInventory) {
      ref.read(retailTabProvider.notifier).state = 'inventory';
    } else if (step.id == StoryStepId.openPos) {
      ref.read(retailTabProvider.notifier).state = 'checkout';
    } else if (step.id == StoryStepId.openReceipts) {
      ref.read(retailTabProvider.notifier).state = 'receipts';
    } else if (step.id == StoryStepId.openAnalytics) {
      ref.read(retailTabProvider.notifier).state = 'analytics';
    }

    if (step.id == StoryStepId.done) {
      skipRetailStory(ref);
      return;
    }
    if (step.requireProduct || step.requireCartItem || step.requireOrder) {
      // Waiting for live action — primary just focuses tab
      if (step.targetTab != null) {
        ref.read(retailTabProvider.notifier).state = step.targetTab!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
      return;
    }
    _goNext(steps, index);
  }

  void _goNext(List<StoryStep> steps, int index) {
    if (index >= steps.length - 1) {
      skipRetailStory(ref);
      return;
    }
    final next = index + 1;
    ref.read(storyStepIndexProvider.notifier).state = next;
    final nextStep = steps[next];
    if (nextStep.targetTab != null) {
      ref.read(retailTabProvider.notifier).state = nextStep.targetTab!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHole());
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.index,
    required this.total,
    required this.step,
    required this.waitingOnAction,
    required this.onSkip,
    required this.onPrimary,
    required this.onFocusTarget,
    this.onBack,
  });

  final int index;
  final int total;
  final StoryStep step;
  final bool waitingOnAction;
  final VoidCallback onSkip;
  final VoidCallback onPrimary;
  final VoidCallback onFocusTarget;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 16,
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.restaurant, Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Story ${index + 1}/$total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (waitingOnAction) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Do the highlighted action…',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate500),
                    ),
                  ],
                  const Spacer(),
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                step.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.slate600,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onBack != null)
                    TextButton(onPressed: onBack, child: const Text('Back')),
                  const Spacer(),
                  if (waitingOnAction)
                    OutlinedButton.icon(
                      onPressed: onFocusTarget,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Show me'),
                    )
                  else
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.slate900,
              foregroundColor: Colors.white,
                      ),
                      child: Text(step.actionLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
