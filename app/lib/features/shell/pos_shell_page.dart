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
import '../billing/upgrade_premium_dialog.dart';
import '../reports/reports_hub_view.dart';
import '../cart_checkout/mobile_cart_fab.dart';
import '../cart_checkout/retail_cart_tray.dart';
import '../onboarding/retail_story_overlay.dart';
import '../onboarding/story_mode.dart';
import '../orders/sales_history_view.dart';
import '../notifications/store_notifications_view.dart';
import '../platform_ops/platform_ops_view.dart';
import '../pos_retail/retail_inventory_view.dart';
import '../pos_retail/retail_pos_view.dart';
import '../promos/discount_codes_view.dart';
import '../receipts/receipts_audit_view.dart';
import '../register/cash_register_view.dart';
import '../support/store_support_view.dart';
import 'casinpos_sidebar.dart';
import 'mobile_account_sheet.dart';
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
      case 'promos':
        body = const DiscountCodesView();
      case 'register':
        body = const CashRegisterView();
      case 'orders':
        body = const SalesHistoryView();
      case 'receipts':
        body = const ReceiptsAuditView();
      case 'analytics':
        body = const SalesAnalyticsView();
      case 'reports':
        body = const ReportsHubView();
      case 'ops':
        body = const PlatformOpsView();
      case 'notifications':
        body = const StoreNotificationsView();
      case 'support':
        body = const StoreSupportView();
      default:
        body = RetailPosView(
          onOpenInventory: () => ref.read(retailTabProvider.notifier).state = 'inventory',
        );
    }

    final storeName = membership?.store.name ?? 'CasinPOS';
    final shell = !showSidebar
        ? Scaffold(
            // Keep content below Dynamic Island / status bar; nav bar owns the bottom.
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (membership?.store.planTier == PlanTier.free &&
                            membership?.role.canManageBilling == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TextButton(
                              onPressed: () => showUpgradePremiumDialog(
                                context,
                                reason: UpgradeReason.general,
                                storeName: storeName,
                                storeId: membership?.storeId,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                backgroundColor: AppColors.brandYellow,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'Upgrade',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        const MobileAccountButton(),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 3,
              selectedIndex: _mobileIndex(tab),
              onDestinationSelected: (i) {
                ref.read(retailTabProvider.notifier).state = switch (i) {
                  0 => 'checkout',
                  1 => 'inventory',
                  2 => 'orders',
                  3 => 'receipts',
                  _ => 'reports',
                };
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'POS'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
                NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Sales'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Receipts'),
                NavigationDestination(icon: Icon(Icons.assessment_outlined), label: 'Reports'),
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

    // Keep cart control OUT of Scaffold.floatingActionButton — FAB slot
    // transitions paint a dark band over NavigationBar on every cart add.
    return Stack(
      children: [
        shell,
        if (!showSidebar && tab == 'checkout')
          Positioned(
            right: 16,
            bottom: 72 + 16, // NavigationBarTheme height + padding
            child: const MobileCartFab(),
          ),
        const RetailStoryOverlay(),
      ],
    );
  }

  int _mobileIndex(String tab) => switch (tab) {
        'checkout' => 0,
        'inventory' => 1,
        'orders' => 2,
        'receipts' => 3,
        'reports' || 'analytics' => 4,
        _ => 0,
      };
}
