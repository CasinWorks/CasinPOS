import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/images/product_image_cache.dart';
import '../../core/theme/app_colors.dart';

/// Renders a catalog photo from URL (disk-cached), pending bytes, or placeholder.
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

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, width: width, height: height, fit: fit);
    } else if (_hasUrl) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final memW = width != null ? (width! * dpr).round() : null;
      final memH = height != null ? (height! * dpr).round() : null;
      child = CachedNetworkImage(
        imageUrl: imageUrl!.trim(),
        cacheManager: ProductImageCache.instance,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memW,
        memCacheHeight: memH,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 80),
        placeholder: (_, _) => _Placeholder(iconSize: iconSize, loading: true),
        errorWidget: (_, _, _) => _Placeholder(iconSize: iconSize),
      );
    } else {
      child = _Placeholder(iconSize: iconSize);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: child,
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
                width: iconSize,
                height: iconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.image_outlined, size: iconSize, color: AppColors.slate400),
      ),
    );
  }
}
