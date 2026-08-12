import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for product photos on iOS / Android.
///
/// Photos stay on device for [stalePeriod] so reopening the app does not
/// re-download every catalog image. Web uses the browser cache instead.
abstract final class ProductImageCache {
  static const key = 'casinposProductImages';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// Warm the disk cache in the background after catalog load (native only).
  static Future<void> prefetch(Iterable<String?> urls) async {
    if (kIsWeb) return;
    final seen = <String>{};
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      try {
        await instance.downloadFile(url);
      } catch (_) {
        // Ignore single failures — placeholder shows until next try.
      }
    }
  }

  static Future<void> remove(String? url) async {
    if (kIsWeb) return;
    final u = url?.trim() ?? '';
    if (u.isEmpty) return;
    try {
      await instance.removeFile(u);
    } catch (_) {}
  }
}
