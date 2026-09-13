import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/providers/pos_providers.dart';
import '../../data/providers/session_providers.dart';

/// Customer-facing dual-screen view for a paired native device.
class CustomerDisplayPage extends ConsumerWidget {
  const CustomerDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider);
    final storeId = membership?.storeId;
    final asyncSnap = storeId == null
        ? const AsyncValue.data(null)
        : ref.watch(customerDisplaySnapshotProvider(storeId));

    final snap = asyncSnap.valueOrNull;
    final empty = snap == null || snap.lines.isEmpty;
    final connecting = storeId != null && asyncSnap.isLoading && snap == null;
    final storeName = snap?.storeName ?? membership?.store.name;

    return Scaffold(
      backgroundColor: AppColors.slate900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandLogo(size: 48, radius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName ?? 'CasinPOS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          storeId == null
                              ? 'Sign in and select a store'
                              : connecting
                                  ? 'Connecting…'
                                  : empty
                                      ? 'Waiting for order…'
                                      : 'Your order',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!empty)
                    Text(
                      '${snap.itemCount} item${snap.itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.retail,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Exit display',
                    onPressed: () => context.go('/'),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: empty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              storeId == null
                                  ? 'Open POS on another device and add items'
                                  : 'Items appear here as they are added',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: snap.lines.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        itemBuilder: (context, i) {
                          final line = snap.lines[i];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${line.quantity}×',
                                style: const TextStyle(
                                  color: AppColors.retail,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${snap.currencySymbol}${line.unitPrice.toStringAsFixed(2)} each',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${snap.currencySymbol}${line.lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A2100), Color(0xFF151515)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      empty
                          ? '${snap?.currencySymbol ?? '₱'}0.00'
                          : '${snap.currencySymbol}${snap.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.retail,
                        fontWeight: FontWeight.w900,
                        fontSize: 40,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
