import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for product photos on iOS / Android (and web where supported).
///
/// Photos stay on device for [stalePeriod] so reopening the app does not
/// re-download every catalog image.
abstract final class ProductImageCache {
  static const key = 'casinposProductImages';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 500,
    ),
  );

  /// Warm the disk cache in the background after catalog load.
  static Future<void> prefetch(Iterable<String?> urls) async {
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
    final u = url?.trim() ?? '';
    if (u.isEmpty) return;
    try {
      await instance.removeFile(u);
    } catch (_) {}
  }
}
