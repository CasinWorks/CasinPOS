import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../domain/enums.dart';

/// Unified CasinPOS brand; icon/accent shifts by business type.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.businessType = BusinessType.restaurant,
    this.compact = false,
  });

  final BusinessType businessType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isRestaurant = businessType == BusinessType.restaurant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: isRestaurant ? AppColors.restaurant : AppColors.slate900,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            isRestaurant ? Icons.local_cafe_rounded : Icons.storefront_rounded,
            color: isRestaurant ? Colors.white : AppColors.retail,
            size: compact ? 18 : 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Casin',
                  style: GoogleFonts.fraunces(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppColors.ink,
                  ),
                ),
                TextSpan(
                  text: 'POS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: isRestaurant ? AppColors.restaurant : AppColors.ink,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
