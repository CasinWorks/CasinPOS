import 'dart:async';
import 'dart:convert';

import 'cart_display_sync_platform.dart'
    if (dart.library.html) 'cart_display_sync_platform_web.dart' as platform;

class CartDisplayLine {
  const CartDisplayLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };

  factory CartDisplayLine.fromJson(Map<String, dynamic> json) => CartDisplayLine(
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      );
}

class CartDisplaySnapshot {
  const CartDisplaySnapshot({
    required this.storeName,
    required this.currencySymbol,
    required this.lines,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.updatedAtMs,
  });

  final String storeName;
  final String currencySymbol;
  final List<CartDisplayLine> lines;
  final double subtotal;
  final double tax;
  final double total;
  final int updatedAtMs;

  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'currencySymbol': currencySymbol,
        'lines': lines.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'updatedAtMs': updatedAtMs,
      };

  factory CartDisplaySnapshot.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return CartDisplaySnapshot(
      storeName: json['storeName'] as String? ?? 'CasinPOS',
      currencySymbol: json['currencySymbol'] as String? ?? '₱',
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map((e) => CartDisplayLine.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  static CartDisplaySnapshot? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CartDisplaySnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

void publishCartDisplay(CartDisplaySnapshot snapshot) {
  platform.publishRaw(snapshot.encode());
}

CartDisplaySnapshot? readCartDisplay() {
  return CartDisplaySnapshot.tryParse(platform.readRaw());
}

Stream<CartDisplaySnapshot?> watchCartDisplay({
  Duration pollInterval = const Duration(milliseconds: 400),
}) async* {
  var lastMs = readCartDisplay()?.updatedAtMs;
  yield readCartDisplay();
  await for (final _ in platform.rawChangeTicks(pollInterval: pollInterval)) {
    final next = readCartDisplay();
    final nextMs = next?.updatedAtMs;
    if (nextMs != lastMs) {
      lastMs = nextMs;
      yield next;
    }
  }
}
