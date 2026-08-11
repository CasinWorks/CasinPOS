import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Renders a catalog photo from URL, pending bytes, or a placeholder.
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
      child = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Placeholder(iconSize: iconSize),
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
  const _Placeholder({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.slate200,
      child: Center(
        child: Icon(Icons.image_outlined, size: iconSize, color: AppColors.slate400),
      ),
    );
  }
}
