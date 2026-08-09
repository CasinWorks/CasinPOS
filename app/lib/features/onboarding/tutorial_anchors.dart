import 'package:flutter/material.dart';

enum TutorialAnchor {
  navInventory,
  addProductBtn,
  navPos,
  productArea,
  payButton,
  navReceipts,
  navAnalytics,
  analyticsPeriod,
}

/// Global keys for story spotlight targets.
abstract final class TutorialAnchors {
  static final Map<TutorialAnchor, GlobalKey> keys = {
    for (final a in TutorialAnchor.values) a: GlobalKey(debugLabel: a.name),
  };

  static GlobalKey key(TutorialAnchor a) => keys[a]!;

  static Rect? rectOf(TutorialAnchor a, {double pad = 8}) {
    final ctx = keys[a]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      topLeft.dx - pad,
      topLeft.dy - pad,
      box.size.width + pad * 2,
      box.size.height + pad * 2,
    ).inflate(0);
  }
}

/// Wraps a control so the story can spotlight it.
class TutorialTarget extends StatelessWidget {
  const TutorialTarget({
    super.key,
    required this.anchor,
    required this.child,
  });

  final TutorialAnchor anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: TutorialAnchors.key(anchor),
      child: child,
    );
  }
}
