import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/store_models.dart';
import '../../../data/providers/pos_providers.dart';
import '../../../data/providers/session_providers.dart';
import '../../../data/providers/sync_providers.dart';
import '../../../domain/enums.dart';
import '../analytics/sales_analytics_view.dart';
import '../cart_checkout/retail_cart_tray.dart';
import '../onboarding/retail_story_overlay.dart';
import '../onboarding/story_mode.dart';
import '../orders/sales_history_view.dart';
import '../platform_ops/platform_ops_view.dart';
import '../pos_retail/retail_inventory_view.dart';
import '../pos_retail/retail_pos_view.dart';
import '../receipts/receipts_audit_view.dart';
import '../register/cash_register_view.dart';
import 'casinpos_sidebar.dart';
import 'phase1_home_page.dart';

/// Retail / Restaurant shell. Retail includes story-mode tutorial.
class PosShellPage extends ConsumerStatefulWidget {
  const PosShellPage({super.key});

  @override
  ConsumerState<PosShellPage> createState() => _PosShellPageState();
}

class _PosShellPageState extends ConsumerState<PosShellPage> {
  String? _loadedStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final membership = ref.read(activeMembershipProvider);
      if (membership?.store.businessType == BusinessType.retail &&
          !ref.read(tutorialCompletedProvider) &&
          !ref.read(storyModeActiveProvider)) {
        startRetailStory(ref);
      }
    });
  }

  Future<void> _syncCatalog(StoreMembership? membership) async {
    final storeId = membership?.storeId;
    if (storeId == null) {
      if (_loadedStoreId != null) {
        _loadedStoreId = null;
        ref.read(posCatalogProvider.notifier).clearLocal();
        ref.read(ordersProvider.notifier).clearLocal();
      }
      return;
    }
    if (_loadedStoreId == storeId) return;
    _loadedStoreId = storeId;
    try {
      await Future.wait([
        ref.read(posCatalogProvider.notifier).loadForStore(storeId),
        ref.read(ordersProvider.notifier).loadForStore(storeId),
        ref.read(cashRegisterProvider.notifier).refresh(),
      ]);
    } catch (_) {
      // Keep empty catalog; inventory actions surface errors on write.
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider);
    ref.listen<StoreMembership?>(activeMembershipProvider, (prev, next) {
      _syncCatalog(next);
    });
    if (_loadedStoreId != membership?.storeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncCatalog(membership));
    }
    final type = membership?.store.businessType ?? BusinessType.retail;

    if (type == BusinessType.restaurant) {
      return const Phase1HomePage();
    }

    final tab = ref.watch(retailTabProvider);
    final orderCount = ref.watch(paidOrdersProvider).length;
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = Breakpoints.useSidebar(width);
    final showCart = Breakpoints.useCartTray(width);
    ref.watch(cartDisplaySyncProvider);
    ref.watch(syncBootstrapProvider);

    Widget body;
    switch (tab) {
      case 'inventory':
        body = const RetailInventoryView();
      case 'register':
        body = const CashRegisterView();
      case 'orders':
        body = const SalesHistoryView();
      case 'receipts':
        body = const ReceiptsAuditView();
      case 'analytics':
        body = const SalesAnalyticsView();
      case 'ops':
        body = const PlatformOpsView();
      case 'notifications':
      case 'support':
        body = _PlaceholderPane(title: tab == 'support' ? 'Support' : 'Notifications');
      default:
        body = RetailPosView(
          onOpenInventory: () => ref.read(retailTabProvider.notifier).state = 'inventory',
        );
    }

    final shell = !showSidebar
        ? Scaffold(
            body: body,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (sheetContext) {
                    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
                    return SizedBox(
                      height: maxHeight,
                      child: const RetailCartTray(),
                    );
                  },
                );
              },
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              label: const Text('Cart'),
              icon: const Icon(Icons.shopping_bag),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _mobileIndex(tab),
              onDestinationSelected: (i) {
                ref.read(retailTabProvider.notifier).state = switch (i) {
                  0 => 'checkout',
                  1 => 'inventory',
                  2 => 'orders',
                  3 => 'receipts',
                  _ => 'analytics',
                };
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'POS'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
                NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Sales'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Receipts'),
                NavigationDestination(icon: Icon(Icons.trending_up), label: 'Stats'),
              ],
            ),
          )
        : Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: AppSpacing.sidebarWidth,
                  child: CasinPosSidebar(
                    activeTab: tab,
                    onSelectTab: (id) => ref.read(retailTabProvider.notifier).state = id,
                    orderCount: orderCount,
                  ),
                ),
                Expanded(child: body),
                if (showCart)
                  const SizedBox(
                    width: 300,
                    child: RetailCartTray(),
                  ),
              ],
            ),
          );

    return Stack(
      children: [
        shell,
        const RetailStoryOverlay(),
      ],
    );
  }

  int _mobileIndex(String tab) => switch (tab) {
        'checkout' => 0,
        'inventory' => 1,
        'orders' => 2,
        'receipts' => 3,
        'analytics' => 4,
        _ => 0,
      };
}

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title — coming soon',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate400),
      ),
    );
  }
}
