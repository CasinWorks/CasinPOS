import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Long-lived on-device cache for catalog product photos.
///
/// Keyed by URL. New uploads use a new storage path → new URL → fresh download.
/// Unchanged URLs stay on disk and are served from memory/disk on every visit.
abstract final class ProductPhotoCacheManager {
  static const _key = 'casinpos_product_photos_v1';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 800,
    ),
  );
}
