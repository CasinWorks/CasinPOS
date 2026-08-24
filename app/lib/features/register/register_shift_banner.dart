import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/pos_providers.dart';
import 'open_register_flow.dart';

/// Shown on POS / payment screens while the till is closed.
class RegisterShiftBanner extends ConsumerWidget {
  const RegisterShiftBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = ref.watch(cashRegisterProvider).valueOrNull;
    if (register != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFFC2410C)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash register is closed',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Open a shift before taking payments or completing a sale.',
                      style: TextStyle(fontSize: 12, color: AppColors.slate600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => ensureCashRegisterOpenForCheckout(context, ref),
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
