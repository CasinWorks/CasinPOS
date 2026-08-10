import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../../domain/enums.dart';

/// Bundled CasinPOS logo (duck + bag mark).
abstract final class BrandAssets {
  static const logo = 'assets/branding/casinpos_logo.png';
}

/// Logo image only — square mark for avatars, splash, headers.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.radius = 16,
    this.shadow = false,
  });

  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        BrandAssets.logo,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, error, stack) => ColoredBox(
          color: AppColors.accent,
          child: Icon(Icons.storefront_rounded, color: AppColors.ink, size: size * 0.45),
        ),
      ),
    );
  }
}

/// Unified CasinPOS brand row: logo + wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.businessType = BusinessType.retail,
    this.compact = false,
    this.showWordmark = true,
  });

  final BusinessType businessType;
  final bool compact;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 36.0 : 44.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: markSize, radius: compact ? 10 : 12),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'CASIN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' POS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
