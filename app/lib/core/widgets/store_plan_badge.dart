import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../domain/enums.dart';

/// Compact Free / Premium chip for shell headers.
class StorePlanBadge extends StatelessWidget {
  const StorePlanBadge({super.key, required this.plan, this.compact = false});

  final PlanTier? plan;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan == PlanTier.premium;
    final label = isPremium ? 'Premium' : 'Free';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFECFDF5) : AppColors.slate100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPremium ? const Color(0xFF86EFAC) : AppColors.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            size: compact ? 12 : 14,
            color: isPremium ? const Color(0xFF047857) : AppColors.slate500,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              color: isPremium ? const Color(0xFF047857) : AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}
