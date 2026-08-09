import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tutorial_anchors.dart';

/// Local preference: story tutorial completed for this device/session.
final tutorialCompletedProvider = StateProvider<bool>((ref) => false);

/// When true, story overlay is active.
final storyModeActiveProvider = StateProvider<bool>((ref) => false);

final storyStepIndexProvider = StateProvider<int>((ref) => 0);

enum StoryStepId {
  welcome,
  openInventory,
  addProduct,
  openPos,
  addToCart,
  checkout,
  openReceipts,
  openAnalytics,
  done,
}

class StoryStep {
  const StoryStep({
    required this.id,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.targetTab,
    this.highlight,
    this.requireProduct = false,
    this.requireCartItem = false,
    this.requireOrder = false,
  });

  final StoryStepId id;
  final String title;
  final String body;
  final String actionLabel;
  final String? targetTab;
  final TutorialAnchor? highlight;
  final bool requireProduct;
  final bool requireCartItem;
  final bool requireOrder;
}

List<StoryStep> retailStorySteps(String storeName) => [
      StoryStep(
        id: StoryStepId.welcome,
        title: 'Welcome to $storeName',
        body:
            'A quick interactive tour. We’ll highlight exactly what to tap — add a product, sell it, then see live stats.',
        actionLabel: 'Start tour',
      ),
      const StoryStep(
        id: StoryStepId.openInventory,
        title: 'Step 1 · Inventory',
        body: 'Tap the glowing Store Inventory button in the sidebar.',
        actionLabel: 'I tapped Inventory',
        targetTab: 'inventory',
        highlight: TutorialAnchor.navInventory,
      ),
      const StoryStep(
        id: StoryStepId.addProduct,
        title: 'Step 2 · Add a product',
        body:
            'Tap the highlighted “+ Add Product” button. Set name, category, and your price — then save. We advance automatically.',
        actionLabel: 'Waiting…',
        targetTab: 'inventory',
        highlight: TutorialAnchor.addProductBtn,
        requireProduct: true,
      ),
      const StoryStep(
        id: StoryStepId.openPos,
        title: 'Step 3 · Retail POS',
        body: 'Tap the glowing Retail POS button to open your checkout floor.',
        actionLabel: 'I opened POS',
        targetTab: 'checkout',
        highlight: TutorialAnchor.navPos,
      ),
      const StoryStep(
        id: StoryStepId.addToCart,
        title: 'Step 4 · Add to cart',
        body: 'Tap “+ Add” on your product (highlighted area). When it’s in the cart, we continue.',
        actionLabel: 'Waiting…',
        targetTab: 'checkout',
        highlight: TutorialAnchor.productArea,
        requireCartItem: true,
      ),
      const StoryStep(
        id: StoryStepId.checkout,
        title: 'Step 5 · Take payment',
        body:
            'Pick Cash / GCash / Maya / Card, then tap the glowing Pay button. Completing a sale advances the tour.',
        actionLabel: 'Waiting…',
        targetTab: 'checkout',
        highlight: TutorialAnchor.payButton,
        requireOrder: true,
      ),
      const StoryStep(
        id: StoryStepId.openReceipts,
        title: 'Step 6 · Receipts',
        body: 'Tap Receipts Audit to review what you just sold.',
        actionLabel: 'Open Receipts',
        targetTab: 'receipts',
        highlight: TutorialAnchor.navReceipts,
      ),
      const StoryStep(
        id: StoryStepId.openAnalytics,
        title: 'Step 7 · Live stats',
        body:
            'Open Sales Statistics — charts and totals update from your real sales. Try Daily / Week / Month.',
        actionLabel: 'Open Statistics',
        targetTab: 'analytics',
        highlight: TutorialAnchor.navAnalytics,
      ),
      const StoryStep(
        id: StoryStepId.done,
        title: 'You’re ready',
        body:
            'Replay anytime via the sparkle icon. Change Retail ↔ Restaurant in Store Settings when you need to.',
        actionLabel: 'Finish tour',
        highlight: TutorialAnchor.analyticsPeriod,
      ),
    ];

void startRetailStory(WidgetRef ref) {
  ref.read(storyStepIndexProvider.notifier).state = 0;
  ref.read(storyModeActiveProvider.notifier).state = true;
}

void skipRetailStory(WidgetRef ref) {
  ref.read(storyModeActiveProvider.notifier).state = false;
  ref.read(tutorialCompletedProvider.notifier).state = true;
}
