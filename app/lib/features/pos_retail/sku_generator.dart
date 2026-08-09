/// Builds a retail-friendly SKU from a product name, e.g. "Pork Belly" → `PORK-BELLY`.
String generateSkuFromName(
  String name, {
  Iterable<String> existingSkus = const [],
}) {
  final words = name
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  if (words.isEmpty) return '';

  var base = words.join('-');
  if (base.length > 24) {
    if (words.length == 1) {
      base = words.first.substring(0, 24);
    } else {
      final initials = words.map((w) => w[0]).join();
      final shortened = '$initials-${words.last}';
      base = shortened.length <= 24 ? shortened : shortened.substring(0, 24);
    }
  }

  final taken = existingSkus
      .map((s) => s.trim().toUpperCase())
      .where((s) => s.isNotEmpty)
      .toSet();

  var candidate = base;
  var n = 2;
  while (taken.contains(candidate) && n < 1000) {
    final suffix = '-$n';
    final maxBase = (24 - suffix.length).clamp(1, 24);
    final prefix = base.length <= maxBase ? base : base.substring(0, maxBase);
    candidate = '$prefix$suffix';
    n++;
  }
  return candidate;
}
