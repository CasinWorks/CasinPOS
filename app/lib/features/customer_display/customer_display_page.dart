import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/cart_display_sync.dart';

/// Customer-facing dual-screen view — intended for a second monitor / browser tab.
class CustomerDisplayPage extends StatefulWidget {
  const CustomerDisplayPage({super.key});

  @override
  State<CustomerDisplayPage> createState() => _CustomerDisplayPageState();
}

class _CustomerDisplayPageState extends State<CustomerDisplayPage> {
  StreamSubscription<CartDisplaySnapshot?>? _sub;
  CartDisplaySnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = readCartDisplay();
    _sub = watchCartDisplay().listen((s) {
      if (!mounted) return;
      setState(() => _snapshot = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    final empty = snap == null || snap.lines.isEmpty;

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
                          snap?.storeName ?? 'CasinPOS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          empty ? 'Waiting for order…' : 'Your order',
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
                              'Items appear here as they are added',
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
                                        color: Colors.white.withValues(alpha: 0.45),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A2100), Color(0xFF151515)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
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
