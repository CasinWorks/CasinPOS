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

  bool get isLowStock => stock <= lowStockThreshold;

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

  double get lineTotal => product.price * quantity;

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
  });

  final String id;
  final String orderNo;
  final List<({String name, int qty, double unitPrice, String category})> items;
  final double subtotal;
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final String timestampLabel;
  final DateTime createdAt;
  final String status;

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isVoided => status.toLowerCase() == 'voided';
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
