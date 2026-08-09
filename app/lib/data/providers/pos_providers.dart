import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../models/demo_catalog.dart';
import '../models/pos_models.dart';
import '../repositories/cash_register_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/transaction_repository.dart';
import 'session_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(),
);

final cashRegisterRepositoryProvider = Provider<CashRegisterRepository>(
  (ref) => CashRegisterRepository(ref.watch(transactionRepositoryProvider)),
);

class PosCatalogNotifier extends StateNotifier<List<RetailProduct>> {
  PosCatalogNotifier(this._ref) : super(List.from(demoRetailCatalog));

  final Ref _ref;
  bool _loading = false;

  ProductRepository get _repo => _ref.read(productRepositoryProvider);

  String? get _storeId => _ref.read(activeMembershipProvider)?.storeId;

  bool get canPersist => isSupabaseReady && _storeId != null;

  Future<void> loadForStore(String storeId) async {
    if (!isSupabaseReady || _loading) return;
    _loading = true;
    try {
      final products = await _repo.fetchRetailProducts(storeId);
      if (!mounted) return;
      state = products;
      final cats = _ref.read(catalogCategoriesProvider.notifier);
      for (final p in products) {
        cats.ensure(p.category);
      }
    } finally {
      _loading = false;
    }
  }

  void clearLocal() {
    state = const [];
  }

  Future<void> restock(String id, double delta) async {
    final index = state.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final updated = state[index].copyWith(
      stock: (state[index].stock + delta).clamp(0, 999999),
    );
    final next = [...state];
    next[index] = updated;
    state = next;
    if (!canPersist) return;
    await _repo.updateStock(productId: id, stock: updated.stock);
  }

  Future<void> restockVoidedLines(List<({String productId, double qty})> lines) async {
    for (final line in lines) {
      await restock(line.productId, line.qty);
    }
  }

  Future<void> deductForSale(List<CartLine> lines) async {
    state = [
      for (final p in state)
        p.copyWith(
          stock: (p.stock -
                  lines
                      .where((l) => l.product.id == p.id)
                      .fold<int>(0, (s, l) => s + l.quantity))
              .clamp(0, 999999)
              .toDouble(),
        ),
    ];
    if (!canPersist) return;
    for (final p in state) {
      if (lines.any((l) => l.product.id == p.id)) {
        await _repo.updateStock(productId: p.id, stock: p.stock);
      }
    }
  }

  Future<RetailProduct> addProduct(RetailProduct product) async {
    final storeId = _storeId;
    if (storeId == null || !isSupabaseReady) {
      state = [product, ...state];
      _ref.read(catalogCategoriesProvider.notifier).ensure(product.category);
      return product;
    }
    final saved = await _repo.upsertRetailProduct(storeId: storeId, product: product);
    state = [saved, ...state.where((p) => p.id != saved.id)];
    _ref.read(catalogCategoriesProvider.notifier).ensure(saved.category);
    return saved;
  }

  Future<RetailProduct> updateProduct(RetailProduct product) async {
    final storeId = _storeId;
    if (storeId == null || !isSupabaseReady) {
      state = [
        for (final p in state)
          if (p.id == product.id) product else p,
      ];
      _ref.read(catalogCategoriesProvider.notifier).ensure(product.category);
      return product;
    }
    final saved = await _repo.upsertRetailProduct(storeId: storeId, product: product);
    state = [
      for (final p in state)
        if (p.id == saved.id) saved else p,
    ];
    _ref.read(catalogCategoriesProvider.notifier).ensure(saved.category);
    return saved;
  }

  Future<void> removeProduct(String id) async {
    state = [for (final p in state) if (p.id != id) p];
    if (!canPersist) return;
    await _repo.deleteProduct(id);
  }
}

class CatalogCategoriesNotifier extends StateNotifier<List<String>> {
  /// Starts empty — categories appear from inventory products (and any you add).
  CatalogCategoriesNotifier() : super(const []);

  void ensure(String category) {
    final name = category.trim();
    if (name.isEmpty) return;
    final exists = state.any((c) => c.toLowerCase() == name.toLowerCase());
    if (exists) return;
    state = [...state, name]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void add(String category) => ensure(category);

  void rename(String from, String to) {
    final next = to.trim();
    if (next.isEmpty) return;
    state = [
      for (final c in state)
        if (c.toLowerCase() == from.toLowerCase()) next else c,
    ];
    ensure(next);
  }

  void remove(String category) {
    state = [
      for (final c in state)
        if (c.toLowerCase() != category.toLowerCase()) c,
    ];
  }

  /// Drop unused saved labels; keep only categories still present on products.
  void syncToInventory(Iterable<String> usedOnProducts) {
    final used = {
      for (final c in usedOnProducts)
        if (c.trim().isNotEmpty) c.trim(),
    };
    state = [
      for (final c in state)
        if (used.any((u) => u.toLowerCase() == c.toLowerCase())) c,
    ];
  }
}

class CartNotifier extends StateNotifier<List<CartLine>> {
  CartNotifier(this._ref) : super(const []);

  final Ref _ref;

  double _liveStock(String productId) {
    final match = _ref.read(posCatalogProvider).where((p) => p.id == productId).firstOrNull;
    return match?.stock ?? 0;
  }

  int _qtyInCart(String productId) {
    final i = state.indexWhere((l) => l.product.id == productId);
    return i >= 0 ? state[i].quantity : 0;
  }

  /// Adds 1 unit. Throws [StockLimitException] when stock is insufficient.
  void add(RetailProduct product) {
    final stock = _liveStock(product.id);
    final inCart = _qtyInCart(product.id);
    if (stock <= 0) {
      throw StockLimitException('${product.name} is out of stock');
    }
    if (inCart + 1 > stock) {
      throw StockLimitException(
        'Only ${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 1)} left for ${product.name}',
      );
    }

    final i = state.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      final updated = [...state];
      updated[i] = updated[i].copyWith(quantity: updated[i].quantity + 1);
      state = updated;
    } else {
      // Prefer live catalog product so stock/price stay current.
      final live = _ref.read(posCatalogProvider).where((p) => p.id == product.id).firstOrNull ?? product;
      state = [...state, CartLine(product: live, quantity: 1)];
    }
  }

  /// Changes qty. Throws [StockLimitException] when increasing past stock.
  void updateQty(int index, int delta) {
    if (index < 0 || index >= state.length) return;
    final line = state[index];
    final next = line.quantity + delta;
    if (next <= 0) {
      final updated = [...state]..removeAt(index);
      state = updated;
      return;
    }
    if (delta > 0) {
      final stock = _liveStock(line.product.id);
      if (next > stock) {
        throw StockLimitException(
          stock <= 0
              ? '${line.product.name} is out of stock'
              : 'Only ${stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 1)} in stock for ${line.product.name}',
        );
      }
    }
    final updated = [...state];
    updated[index] = line.copyWith(quantity: next);
    state = updated;
  }

  /// Validates entire cart against live stock before checkout.
  void assertWithinStock() {
    for (final line in state) {
      final stock = _liveStock(line.product.id);
      if (line.quantity > stock) {
        throw StockLimitException(
          stock <= 0
              ? '${line.product.name} is out of stock — remove it from cart'
              : '${line.product.name}: cart has ${line.quantity}, only ${stock.toStringAsFixed(0)} left',
        );
      }
    }
  }

  void removeAt(int index) {
    final updated = [...state]..removeAt(index);
    state = updated;
  }

  void syncProduct(RetailProduct product) {
    state = [
      for (final line in state)
        if (line.product.id == product.id) line.copyWith(product: product) else line,
    ];
  }

  void removeProduct(String productId) {
    state = [for (final line in state) if (line.product.id != productId) line];
  }

  void clear() => state = const [];
}

class OrdersNotifier extends StateNotifier<List<PosOrder>> {
  OrdersNotifier(this._ref) : super(List.from(demoSeedOrders));

  final Ref _ref;

  TransactionRepository get _repo => _ref.read(transactionRepositoryProvider);

  Future<void> loadForStore(String storeId) async {
    if (!isSupabaseReady) return;
    try {
      state = await _repo.fetchPaidOrders(storeId);
    } catch (_) {
      // Keep local list if offline / schema not migrated yet.
    }
  }

  void clearLocal() => state = const [];

  void add(PosOrder order) => state = [order, ...state];

  Future<({PosOrder order, String? warning})> completeSale({
    required List<CartLine> lines,
    required double subtotal,
    required double tax,
    required double total,
    required PaymentMethod paymentMethod,
    required double cashReceived,
    required double changeGiven,
  }) async {
    final membership = _ref.read(activeMembershipProvider);
    PosOrder order;
    String? warning;

    if (membership == null) {
      throw AppException('No active store. Sign in and open your store again.');
    }

    if (isSupabaseReady) {
      try {
        order = await _repo.createPaidSale(
          storeId: membership.storeId,
          businessType: membership.store.businessType,
          lines: lines,
          subtotal: subtotal,
          tax: tax,
          total: total,
          paymentMethod: paymentMethod,
          cashReceived: cashReceived,
          changeGiven: changeGiven,
          currencyCode: membership.store.currencyCode,
        );
      } catch (e) {
        // Keep the shift moving, but make the sync failure visible.
        order = PosOrder(
          id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
          orderNo: '#FP-${DateTime.now().millisecondsSinceEpoch % 100000}',
          items: [
            for (final l in lines)
              (
                name: l.product.name,
                qty: l.quantity,
                unitPrice: l.product.price,
                category: l.product.category,
              ),
          ],
          subtotal: subtotal,
          tax: tax,
          total: total,
          paymentMethod: paymentMethod,
          timestampLabel: 'Just now',
          createdAt: DateTime.now(),
        );
        warning = 'Sale completed on this device, but cloud save failed: ${friendlyError(e)}';
      }
    } else {
      order = PosOrder(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        orderNo: '#FP-${DateTime.now().millisecondsSinceEpoch % 100000}',
        items: [
          for (final l in lines)
            (
              name: l.product.name,
              qty: l.quantity,
              unitPrice: l.product.price,
              category: l.product.category,
            ),
        ],
        subtotal: subtotal,
        tax: tax,
        total: total,
        paymentMethod: paymentMethod,
        timestampLabel: 'Just now',
        createdAt: DateTime.now(),
      );
      warning = 'Offline mode — sale saved on this device only.';
    }
    state = [order, ...state];
    return (order: order, warning: warning);
  }

  Future<void> voidSale({
    required PosOrder order,
    String? reason,
  }) async {
    if (order.status.toLowerCase() == 'voided') {
      throw StateError('This sale is already voided.');
    }

    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(order.id);

    if (isUuid && isSupabaseReady) {
      final lines = await _repo.voidSale(
        transactionId: order.id,
        reason: reason,
      );
      await _ref.read(posCatalogProvider.notifier).restockVoidedLines(lines);
    } else {
      // Local-only sale: match catalog by name and restock.
      final catalog = _ref.read(posCatalogProvider);
      for (final item in order.items) {
        final match = catalog.where((p) => p.name == item.name).firstOrNull;
        if (match != null) {
          await _ref.read(posCatalogProvider.notifier).restock(match.id, item.qty.toDouble());
        }
      }
    }

    state = [
      for (final o in state)
        if (o.id == order.id)
          PosOrder(
            id: o.id,
            orderNo: o.orderNo,
            items: o.items,
            subtotal: o.subtotal,
            tax: o.tax,
            total: o.total,
            paymentMethod: o.paymentMethod,
            timestampLabel: o.timestampLabel,
            createdAt: o.createdAt,
            status: 'Voided',
          )
        else
          o,
    ];

    // Cash expected drops when a cash sale is voided.
    if (order.paymentMethod == PaymentMethod.cash) {
      await _ref.read(cashRegisterProvider.notifier).refresh();
    }
  }
}

enum VatMode { inclusive, plusTen }

class CheckoutSettings {
  const CheckoutSettings({
    this.paymentMethod = PaymentMethod.cash,
    this.vatMode = VatMode.inclusive,
    this.discountPercent = 0,
  });

  final PaymentMethod paymentMethod;
  final VatMode vatMode;
  final double discountPercent;

  CheckoutSettings copyWith({
    PaymentMethod? paymentMethod,
    VatMode? vatMode,
    double? discountPercent,
  }) {
    return CheckoutSettings(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vatMode: vatMode ?? this.vatMode,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}

class CheckoutSettingsNotifier extends StateNotifier<CheckoutSettings> {
  CheckoutSettingsNotifier() : super(const CheckoutSettings());

  void setPayment(PaymentMethod m) => state = state.copyWith(paymentMethod: m);
  void setVat(VatMode m) => state = state.copyWith(vatMode: m);
  void setDiscount(double p) => state = state.copyWith(discountPercent: p);
}

final posCatalogProvider =
    StateNotifierProvider<PosCatalogNotifier, List<RetailProduct>>(
  (ref) => PosCatalogNotifier(ref),
);

final catalogCategoriesProvider =
    StateNotifierProvider<CatalogCategoriesNotifier, List<String>>(
  (ref) => CatalogCategoriesNotifier(),
);

/// Filter chips: All + only categories that exist on products in inventory.
final retailCategoryFiltersProvider = Provider<List<String>>((ref) {
  final fromProducts = ref
      .watch(posCatalogProvider)
      .map((p) => p.category.trim())
      .where((c) => c.isNotEmpty);
  final sorted = fromProducts.toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return ['All', ...sorted];
});

/// Suggestion chips in the product editor (inventory + any newly created labels).
final productCategorySuggestionsProvider = Provider<List<String>>((ref) {
  final saved = ref.watch(catalogCategoriesProvider);
  final fromProducts = ref
      .watch(posCatalogProvider)
      .map((p) => p.category.trim())
      .where((c) => c.isNotEmpty);
  final merged = <String>{...saved, ...fromProducts};
  return merged.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
});

final cartProvider = StateNotifierProvider<CartNotifier, List<CartLine>>(
  (ref) => CartNotifier(ref),
);

final ordersProvider = StateNotifierProvider<OrdersNotifier, List<PosOrder>>(
  (ref) => OrdersNotifier(ref),
);

/// Paid sales only (voided excluded) — analytics, receipts, register math.
final paidOrdersProvider = Provider<List<PosOrder>>((ref) {
  return ref.watch(ordersProvider).where((o) => o.isPaid).toList();
});

class CashRegisterNotifier extends StateNotifier<AsyncValue<RegisterBalance?>> {
  CashRegisterNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  CashRegisterRepository get _repo => _ref.read(cashRegisterRepositoryProvider);

  Future<void> refresh() async {
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (storeId == null || !isSupabaseReady) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repo.fetchOpenSession(storeId);
      if (session == null) return null;
      return _repo.computeBalance(session);
    });
  }

  Future<void> open({required double openingFloat, String? notes}) async {
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (storeId == null) throw StateError('No active store');
    await _repo.openSession(
      storeId: storeId,
      openingFloat: openingFloat,
      notes: notes,
    );
    await refresh();
  }

  Future<void> payIn({required double amount, String? note}) async {
    final balance = state.valueOrNull;
    if (balance == null) throw StateError('Open the register first');
    await _repo.addMovement(
      sessionId: balance.session.id,
      kind: 'pay_in',
      amount: amount,
      note: note,
    );
    await refresh();
  }

  Future<void> payOut({required double amount, String? note}) async {
    final balance = state.valueOrNull;
    if (balance == null) throw StateError('Open the register first');
    await _repo.addMovement(
      sessionId: balance.session.id,
      kind: 'pay_out',
      amount: amount,
      note: note,
    );
    await refresh();
  }

  Future<CashSession> close({required double closingCount, String? notes}) async {
    final balance = state.valueOrNull;
    if (balance == null) throw StateError('No open session');
    final closed = await _repo.closeSession(
      session: balance.session,
      closingCount: closingCount,
      notes: notes,
    );
    await refresh();
    return closed;
  }
}

final cashRegisterProvider =
    StateNotifierProvider<CashRegisterNotifier, AsyncValue<RegisterBalance?>>(
  (ref) => CashRegisterNotifier(ref),
);

final checkoutSettingsProvider =
    StateNotifierProvider<CheckoutSettingsNotifier, CheckoutSettings>(
  (ref) => CheckoutSettingsNotifier(),
);

final retailTabProvider = StateProvider<String>((ref) => 'checkout');

class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double tax;
  final double total;
}

final cartTotalsProvider = Provider<CartTotals>((ref) {
  final cart = ref.watch(cartProvider);
  final settings = ref.watch(checkoutSettingsProvider);
  final gross = cart.fold<double>(0, (s, l) => s + l.lineTotal);
  final discount = gross * (settings.discountPercent / 100);
  final afterDiscount = gross - discount;

  if (settings.vatMode == VatMode.inclusive) {
    return CartTotals(
      subtotal: afterDiscount,
      discount: discount,
      tax: 0,
      total: afterDiscount,
    );
  }

  final tax = afterDiscount * 0.10;
  return CartTotals(
    subtotal: afterDiscount,
    discount: discount,
    tax: tax,
    total: afterDiscount + tax,
  );
});
