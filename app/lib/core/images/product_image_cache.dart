import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Optional background warm of HTTP cache on native (best-effort).
/// Display uses [Image.network]; this only helps subsequent loads.
abstract final class ProductImageCache {
  static CacheManager get instance => DefaultCacheManager();

  static Future<void> prefetch(Iterable<String?> urls) async {
    if (kIsWeb) return;
    final seen = <String>{};
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      try {
        await instance.downloadFile(url);
      } catch (_) {}
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
