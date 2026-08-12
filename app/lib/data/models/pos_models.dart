class RetailProduct {
  const RetailProduct({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.weight,
    required this.stock,
    required this.lowStockThreshold,
    required this.imageUrl,
    this.description = '',
    this.barcode,
    this.salePrice,
    this.saleStartsAt,
    this.saleEndsAt,
  });

  final String id;
  final String sku;
  final String name;
  final String category;
  final double price;
  final double costPrice;
  final String weight;
  final double stock;
  final double lowStockThreshold;
  final String imageUrl;
  final String description;
  final String? barcode;
  final double? salePrice;
  final DateTime? saleStartsAt;
  final DateTime? saleEndsAt;

  bool get isLowStock => stock <= lowStockThreshold;

  /// True when [salePrice] is set and now is inside the optional start/end window.
  bool isOnSaleAt([DateTime? now]) {
    final sale = salePrice;
    if (sale == null || sale < 0 || sale >= price) return false;
    final n = now ?? DateTime.now();
    if (saleStartsAt != null && n.isBefore(saleStartsAt!)) return false;
    if (saleEndsAt != null && n.isAfter(saleEndsAt!)) return false;
    return true;
  }

  bool get isOnSale => isOnSaleAt();

  double get effectivePrice => isOnSale ? salePrice! : price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category': category,
        'price': price,
        'costPrice': costPrice,
        'weight': weight,
        'stock': stock,
        'lowStockThreshold': lowStockThreshold,
        'imageUrl': imageUrl,
        'description': description,
        'barcode': barcode,
        'salePrice': salePrice,
        'saleStartsAt': saleStartsAt?.toUtc().toIso8601String(),
        'saleEndsAt': saleEndsAt?.toUtc().toIso8601String(),
      };

  factory RetailProduct.fromJson(Map<String, dynamic> json) => RetailProduct(
        id: json['id'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
        weight: json['weight'] as String? ?? '',
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toDouble() ?? 5,
        imageUrl: json['imageUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        barcode: json['barcode'] as String?,
        salePrice: (json['salePrice'] as num?)?.toDouble(),
        saleStartsAt: DateTime.tryParse(json['saleStartsAt'] as String? ?? ''),
        saleEndsAt: DateTime.tryParse(json['saleEndsAt'] as String? ?? ''),
      );

  RetailProduct copyWith({
    String? sku,
    String? name,
    String? category,
    double? price,
    double? costPrice,
    String? weight,
    double? stock,
    double? lowStockThreshold,
    String? imageUrl,
    String? description,
    String? barcode,
    double? salePrice,
    DateTime? saleStartsAt,
    DateTime? saleEndsAt,
    bool clearSale = false,
  }) {
    return RetailProduct(
      id: id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      weight: weight ?? this.weight,
      stock: stock ?? this.stock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      salePrice: clearSale ? null : (salePrice ?? this.salePrice),
      saleStartsAt: clearSale ? null : (saleStartsAt ?? this.saleStartsAt),
      saleEndsAt: clearSale ? null : (saleEndsAt ?? this.saleEndsAt),
    );
  }
}

enum DiscountKind { percent, fixed }

class DiscountCode {
  const DiscountCode({
    required this.id,
    required this.storeId,
    required this.code,
    required this.kind,
    required this.value,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String storeId;
  final String code;
  final DiscountKind kind;
  final double value;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool isValidAt([DateTime? now]) {
    if (!isActive) return false;
    final n = now ?? DateTime.now();
    if (startsAt != null && n.isBefore(startsAt!)) return false;
    if (endsAt != null && n.isAfter(endsAt!)) return false;
    return value > 0;
  }

  String get label {
    final upper = code.toUpperCase();
    return kind == DiscountKind.percent
        ? '$upper (${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}%)'
        : '$upper (₱${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} off)';
  }

  double amountOff(double gross) {
    if (gross <= 0 || !isValidAt()) return 0;
    if (kind == DiscountKind.percent) {
      return (gross * (value.clamp(0, 100) / 100)).clamp(0, gross);
    }
    return value.clamp(0, gross);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'code': code,
        'kind': kind.name,
        'value': value,
        'isActive': isActive,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
      };

  factory DiscountCode.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] as String? ?? 'percent').toLowerCase();
    return DiscountCode(
      id: json['id'] as String? ?? '',
      storeId: json['storeId'] as String? ?? json['store_id'] as String? ?? '',
      code: (json['code'] as String? ?? '').trim().toUpperCase(),
      kind: kindRaw == 'fixed' ? DiscountKind.fixed : DiscountKind.percent,
      value: (json['value'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      startsAt: DateTime.tryParse(
        (json['startsAt'] ?? json['starts_at']) as String? ?? '',
      ),
      endsAt: DateTime.tryParse(
        (json['endsAt'] ?? json['ends_at']) as String? ?? '',
      ),
    );
  }

  DiscountCode copyWith({
    String? code,
    DiscountKind? kind,
    double? value,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearWindow = false,
  }) {
    return DiscountCode(
      id: id,
      storeId: storeId,
      code: code ?? this.code,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
      startsAt: clearWindow ? null : (startsAt ?? this.startsAt),
      endsAt: clearWindow ? null : (endsAt ?? this.endsAt),
    );
  }
}

class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
  });

  final RetailProduct product;
  final int quantity;

  double get lineTotal => product.effectivePrice * quantity;

  CartLine copyWith({RetailProduct? product, int? quantity}) => CartLine(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
      );
}

enum PaymentMethod { cash, gcash, maya, card }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.gcash => 'GCash',
        PaymentMethod.maya => 'Maya',
        PaymentMethod.card => 'Card',
      };
}

class OrderLine {
  const OrderLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.category,
    this.productId,
    this.refundedQty = 0,
    this.itemId,
  });

  final String name;
  final int qty;
  final double unitPrice;
  final String category;
  final String? productId;
  final int refundedQty;
  final String? itemId;

  int get refundableQty => (qty - refundedQty).clamp(0, qty);
  double get lineTotal => unitPrice * qty;
  double get refundableTotal => unitPrice * refundableQty;

  OrderLine copyWith({int? refundedQty}) => OrderLine(
        name: name,
        qty: qty,
        unitPrice: unitPrice,
        category: category,
        productId: productId,
        refundedQty: refundedQty ?? this.refundedQty,
        itemId: itemId,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        'category': category,
        'productId': productId,
        'refundedQty': refundedQty,
        'itemId': itemId,
      };

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        name: json['name'] as String? ?? 'Item',
        qty: (json['qty'] as num?)?.round() ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? 'General',
        productId: json['productId'] as String?,
        refundedQty: (json['refundedQty'] as num?)?.round() ?? 0,
        itemId: json['itemId'] as String?,
      );
}

class PosOrder {
  const PosOrder({
    required this.id,
    required this.orderNo,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.timestampLabel,
    required this.createdAt,
    this.status = 'Paid',
    this.synced = true,
    this.refundedTotal = 0,
    this.discountCode,
    this.discountAmount = 0,
  });

  final String id;
  final String orderNo;
  final List<OrderLine> items;
  final double subtotal;
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final String timestampLabel;
  final DateTime createdAt;
  final String status;

  /// Whether this sale has been confirmed in Supabase (false = pending outbox).
  final bool synced;
  final double refundedTotal;
  final String? discountCode;
  final double discountAmount;

  bool get isPaid => status.toLowerCase() == 'paid' || status.toLowerCase() == 'partial refund';
  bool get isVoided => status.toLowerCase() == 'voided';
  bool get isRefunded => status.toLowerCase() == 'refunded';
  bool get isPartiallyRefunded => status.toLowerCase() == 'partial refund';
  bool get canRefund =>
      isPaid && items.any((i) => i.refundableQty > 0) && !isVoided;

  double get netTotal => (total - refundedTotal).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNo': orderNo,
        'items': [for (final i in items) i.toJson()],
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'timestampLabel': timestampLabel,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        'synced': synced,
        'refundedTotal': refundedTotal,
        'discountCode': discountCode,
        'discountAmount': discountAmount,
      };

  factory PosOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final methodRaw = json['paymentMethod'] as String? ?? 'cash';
    return PosOrder(
      id: json['id'] as String? ?? '',
      orderNo: json['orderNo'] as String? ?? '',
      items: rawItems is List
          ? [
              for (final raw in rawItems.whereType<Map>())
                OrderLine.fromJson(Map<String, dynamic>.from(raw)),
            ]
          : const [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == methodRaw,
        orElse: () => PaymentMethod.cash,
      ),
      timestampLabel: json['timestampLabel'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'Paid',
      synced: json['synced'] as bool? ?? true,
      refundedTotal: (json['refundedTotal'] as num?)?.toDouble() ?? 0,
      discountCode: json['discountCode'] as String?,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

const retailCategories = [
  'All',
  'General',
  'Food',
  'Beverages',
  'Household',
  'Other',
];

/// Default seed categories (without the “All” filter chip).
const defaultRetailCategories = [
  'General',
  'Food',
  'Beverages',
  'Household',
  'Other',
];
