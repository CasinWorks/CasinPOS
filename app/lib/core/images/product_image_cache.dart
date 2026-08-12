import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'product_photo_cache_manager.dart';

/// Prefetch / evict API used by catalog sync.
///
/// Downloads each URL **once** to disk, then warms Flutter's memory image
/// cache so POS / Inventory grids paint without a spinner on revisit.
abstract final class ProductImageCache {
  static Future<void> prefetch(Iterable<String?> urls) async {
    final seen = <String>{};
    final list = <String>[];
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      list.add(url);
    }
    if (list.isEmpty) return;

    const chunk = 6;
    for (var i = 0; i < list.length; i += chunk) {
      final slice = list.skip(i).take(chunk);
      await Future.wait(slice.map(_ensureCachedAndWarm));
    }
  }

  static Future<void> _ensureCachedAndWarm(String url) async {
    try {
      final info = await ProductPhotoCacheManager.instance.getFileFromCache(url);
      if (info == null || !await info.file.exists() || await info.file.length() == 0) {
        await ProductPhotoCacheManager.instance.downloadFile(url);
      }
      await _warmMemory(url);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductImageCache: skip $url ($e)');
      }
    }
  }

  /// Decode into Flutter's [ImageCache] so the next [ProductPhoto] build is sync.
  static Future<void> _warmMemory(String url) async {
    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: ProductPhotoCacheManager.instance,
    );
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        image.dispose();
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      stream.removeListener(listener);
    }
  }

  static Future<void> remove(String? url) async {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return;
    try {
      await ProductPhotoCacheManager.instance.removeFile(u);
      // Drop decoded frames for this URL if present.
      PaintingBinding.instance.imageCache.evict(
        CachedNetworkImageProvider(
          u,
          cacheManager: ProductPhotoCacheManager.instance,
        ),
      );
    } catch (_) {}
  }
}
