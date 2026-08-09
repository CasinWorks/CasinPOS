import '../models/pos_models.dart';

/// New retail stores start empty — tutorial teaches adding the first product.
final List<RetailProduct> demoRetailCatalog = [];

/// Optional sample pack (not auto-loaded).
final List<RetailProduct> optionalMeatsSamplePack = [
  const RetailProduct(
    id: 'sample-meat-1',
    sku: 'PM-B001',
    name: 'Thin Sliced Pork Samgyupsal',
    category: 'General',
    price: 88,
    costPrice: 62,
    weight: '500g Pack',
    stock: 45,
    lowStockThreshold: 10,
    imageUrl:
        'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&q=80&w=800',
  ),
];

final List<PosOrder> demoSeedOrders = [];
