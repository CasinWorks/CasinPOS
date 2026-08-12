import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../images/product_photo_cache_manager.dart';
import '../theme/app_colors.dart';

/// Catalog photo with durable memory + disk cache (download once per URL).
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    super.key,
    this.imageUrl,
    this.bytes,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.iconSize = 24,
  });

  final String? imageUrl;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxFit fit;
  final double iconSize;

  bool get _hasUrl => imageUrl != null && imageUrl!.trim().isNotEmpty;

  double? _finite(double? v) {
    if (v == null) return null;
    if (!v.isFinite || v <= 0) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = _finite(width) ?? _finite(constraints.maxWidth);
            final h = _finite(height) ?? _finite(constraints.maxHeight);

            if (bytes != null) {
              return Image.memory(
                bytes!,
                width: w,
                height: h,
                fit: fit,
                gaplessPlayback: true,
              );
            }
            if (!_hasUrl) {
              return _Placeholder(iconSize: iconSize);
            }

            final url = imageUrl!.trim();
            // Decode at display size so grid thumbs stay light in memory.
            final memW = w != null ? (w * MediaQuery.devicePixelRatioOf(context)).round() : null;
            final memH = h != null ? (h * MediaQuery.devicePixelRatioOf(context)).round() : null;

            return CachedNetworkImage(
              imageUrl: url,
              cacheManager: ProductPhotoCacheManager.instance,
              width: w,
              height: h,
              fit: fit,
              filterQuality: FilterQuality.medium,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              useOldImageOnUrlChange: true,
              memCacheWidth: memW,
              memCacheHeight: memH,
              placeholder: (_, _) => _Placeholder(iconSize: iconSize, loading: true),
              errorWidget: (_, _, _) => _Placeholder(iconSize: iconSize),
            );
          },
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.iconSize, this.loading = false});

  final double iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.slate200,
      child: Center(
        child: loading
            ? SizedBox(
                width: iconSize * 0.7,
                height: iconSize * 0.7,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.image_outlined, size: iconSize, color: AppColors.slate400),
      ),
    );
  }
}
