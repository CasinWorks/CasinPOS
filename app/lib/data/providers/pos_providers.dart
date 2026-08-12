import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../../core/images/product_image_cache.dart';
import '../cart_display_sync.dart';
import '../local/local_pos_store.dart';
import '../models/demo_catalog.dart';
import '../models/pos_models.dart';
import '../repositories/cash_register_repository.dart';
import '../repositories/discount_code_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/transaction_repository.dart';
import 'connectivity_providers.dart';
import 'outbox_tick.dart';
import 'session_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(),
);

final discountCodeRepositoryProvider = Provider<DiscountCodeRepository>(
  (ref) => DiscountCodeRepository(),
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
    if (_loading) return;
    _loading = true;
    try {
      // Hydrate device cache first so POS works immediately offline.
      final cached = await LocalPosStore.loadCatalog(storeId);
      if (cached.isNotEmpty && mounted) {
        state = [for (final m in cached) RetailProduct.fromJson(m)];
        final cats = _ref.read(catalogCategoriesProvider.notifier);
        for (final p in state) {
          cats.ensure(p.category);
        }
        // Serve photos from disk immediately; only missing URLs hit the network.
        unawaited(
          ProductImageCache.prefetch(state.map((p) => p.imageUrl)),
        );
      }
      unawaited(_ref.read(discountCodesProvider.notifier).loadForStore(storeId));

      if (!isSupabaseReady) return;
      if (!(_ref.read(cloudReachableProvider))) return;

      final products = await _repo.fetchRetailProducts(storeId);
      if (!mounted) return;
      state = products;
      final cats = _ref.read(catalogCategoriesProvider.notifier);
      for (final p in products) {
        cats.ensure(p.category);
      }
      await LocalPosStore.saveCatalog(
        storeId,
        [for (final p in products) p.toJson()],
      );
      // Warm photo disk cache so reopen / POS grid is instant offline-friendly.
      unawaited(
        ProductImageCache.prefetch(products.map((p) => p.imageUrl)),
      );
      unawaited(_ref.read(discountCodesProvider.notifier).loadForStore(storeId));
    } catch (_) {
      // Keep cached / current catalog if cloud fetch fails.
    } finally {
      _loading = false;
    }
  }

  Future<void> _persistCatalog() async {
    final storeId = _storeId;
    if (storeId == null) return;
    await LocalPosStore.saveCatalog(storeId, [for (final p in state) p.toJson()]);
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
    await _persistCatalog();
    if (!canPersist || !(_ref.read(cloudReachableProvider))) {
      if (canPersist) {
        await LocalPosStore.enqueueOutbox(_storeId!, {
          'id': const Uuid().v4(),
          'kind': 'stock',
          'productId': id,
          'stock': updated.stock,
        });
        bumpOutboxTick(_ref);
      }
      return;
    }
    try {
      await _repo.updateStock(productId: id, stock: updated.stock);
    } catch (_) {
      await LocalPosStore.enqueueOutbox(_storeId!, {
        'id': const Uuid().v4(),
        'kind': 'stock',
        'productId': id,
        'stock': updated.stock,
      });
      bumpOutboxTick(_ref);
    }
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
    await _persistCatalog();
    if (!canPersist) return;
    final online = _ref.read(cloudReachableProvider);
    for (final p in state) {
      if (lines.any((l) => l.product.id == p.id)) {
        if (!online) {
          await LocalPosStore.enqueueOutbox(_storeId!, {
            'id': const Uuid().v4(),
            'kind': 'stock',
            'productId': p.id,
            'stock': p.stock,
          });
          bumpOutboxTick(_ref);
          continue;
        }
        try {
          await _repo.updateStock(productId: p.id, stock: p.stock);
        } catch (_) {
          await LocalPosStore.enqueueOutbox(_storeId!, {
            'id': const Uuid().v4(),
            'kind': 'stock',
            'productId': p.id,
            'stock': p.stock,
          });
          bumpOutboxTick(_ref);
        }
      }
    }
  }

  Future<RetailProduct> addProduct(RetailProduct product) async {
    final storeId = _storeId;
    if (storeId == null || !isSupabaseReady || !(_ref.read(cloudReachableProvider))) {
      state = [product, ...state];
      _ref.read(catalogCategoriesProvider.notifier).ensure(product.category);
      await _persistCatalog();
      return product;
    }
    final saved = await _repo.upsertRetailProduct(storeId: storeId, product: product);
    state = [saved, ...state.where((p) => p.id != saved.id)];
    _ref.read(catalogCategoriesProvider.notifier).ensure(saved.category);
    await _persistCatalog();
    return saved;
  }

  Future<RetailProduct> updateProduct(RetailProduct product) async {
    final storeId = _storeId;
    if (storeId == null || !isSupabaseReady || !(_ref.read(cloudReachableProvider))) {
      state = [
        for (final p in state)
          if (p.id == product.id) product else p,
      ];
      _ref.read(catalogCategoriesProvider.notifier).ensure(product.category);
      await _persistCatalog();
      return product;
    }
    final saved = await _repo.upsertRetailProduct(storeId: storeId, product: product);
    state = [
      for (final p in state)
        if (p.id == saved.id) saved else p,
    ];
    _ref.read(catalogCategoriesProvider.notifier).ensure(saved.category);
    await _persistCatalog();
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
    _ref.read(cartAddPulseProvider.notifier).state = product.id;
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
    final cached = await LocalPosStore.loadOrders(storeId);
    if (cached.isNotEmpty) {
      state = [for (final m in cached) PosOrder.fromJson(m)];
    }

    if (!isSupabaseReady || !(_ref.read(cloudReachableProvider))) return;
    try {
      final remote = await _repo.fetchPaidOrders(storeId);
      // Keep any unsynced local-only sales at the front.
      final pending = state.where((o) => !o.synced).toList();
      final pendingIds = pending.map((o) => o.id).toSet();
      state = [
        ...pending,
        for (final o in remote)
          if (!pendingIds.contains(o.id)) o,
      ];
      await _persistOrders(storeId);
    } catch (_) {
      // Keep cached / current list if offline / schema not migrated yet.
    }
  }

  Future<void> _persistOrders([String? storeId]) async {
    final id = storeId ?? _ref.read(activeMembershipProvider)?.storeId;
    if (id == null) return;
    await LocalPosStore.saveOrders(id, [for (final o in state) o.toJson()]);
  }

  void clearLocal() => state = const [];

  void add(PosOrder order) => state = [order, ...state];

  void markSynced(String localId) {
    state = [
      for (final o in state)
        if (o.id == localId)
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
            status: o.status,
            synced: true,
          )
        else
          o,
    ];
    unawaited(_persistOrders());
  }

  void replaceLocalWithRemote(String localId, PosOrder remote) {
    state = [
      for (final o in state)
        if (o.id == localId) remote else o,
    ];
    unawaited(_persistOrders());
  }

  Future<({PosOrder order, String? warning})> completeSale({
    required List<CartLine> lines,
    required double subtotal,
    required double tax,
    required double total,
    required PaymentMethod paymentMethod,
    required double cashReceived,
    required double changeGiven,
    String? discountCode,
    double discountAmount = 0,
  }) async {
    final membership = _ref.read(activeMembershipProvider);
    if (membership == null) {
      throw AppException('No active store. Sign in and open your store again.');
    }

    final localId = const Uuid().v4();
    final now = DateTime.now();
    var order = PosOrder(
      id: localId,
      orderNo: '#CP-${now.millisecondsSinceEpoch % 1000000}',
      items: [
        for (final l in lines)
          OrderLine(
            name: l.product.name,
            qty: l.quantity,
            unitPrice: l.product.effectivePrice,
            category: l.product.category,
            productId: l.product.id,
          ),
      ],
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      timestampLabel: 'Just now',
      createdAt: now,
      synced: false,
      discountCode: discountCode,
      discountAmount: discountAmount,
    );
    String? warning;

    final outboxPayload = {
      'id': localId,
      'kind': 'sale',
      'localOrderId': localId,
      'lines': [
        for (final l in lines)
          {'product': l.product.toJson(), 'quantity': l.quantity},
      ],
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod.name,
      'cashReceived': cashReceived,
      'changeGiven': changeGiven,
      'currencyCode': membership.store.currencyCode,
      'discountCode': discountCode,
      'discountAmount': discountAmount,
    };

    final online = isSupabaseReady && _ref.read(cloudReachableProvider);
    if (online) {
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
          discountCode: discountCode,
          discountAmount: discountAmount,
        );
      } catch (e) {
        warning = kOfflineQueuedSaleMessage;
        await LocalPosStore.enqueueOutbox(membership.storeId, outboxPayload);
        bumpOutboxTick(_ref);
      }
    } else {
      warning = kOfflineQueuedSaleMessage;
      await LocalPosStore.enqueueOutbox(membership.storeId, outboxPayload);
      bumpOutboxTick(_ref);
    }

    state = [order, ...state];
    await _persistOrders(membership.storeId);

    if (paymentMethod == PaymentMethod.cash) {
      await _ref.read(cashRegisterProvider.notifier).applyLocalCashSale(total);
    }
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

    if (isUuid && isSupabaseReady && _ref.read(cloudReachableProvider)) {
      try {
        final lines = await _repo.voidSale(
          transactionId: order.id,
          reason: reason,
        );
        await _ref.read(posCatalogProvider.notifier).restockVoidedLines(lines);
      } catch (_) {
        await LocalPosStore.enqueueOutbox(
          _ref.read(activeMembershipProvider)!.storeId,
          {
            'id': const Uuid().v4(),
            'kind': 'void',
            'transactionId': order.id,
            'reason': reason,
          },
        );
        bumpOutboxTick(_ref);
        // Local restock by name for immediate inventory correctness.
        final catalog = _ref.read(posCatalogProvider);
        for (final item in order.items) {
          final match = catalog.where((p) => p.name == item.name).firstOrNull;
          if (match != null) {
            await _ref.read(posCatalogProvider.notifier).restock(match.id, item.qty.toDouble());
          }
        }
      }
    } else {
      // Local-only / offline sale: match catalog by name and restock.
      final catalog = _ref.read(posCatalogProvider);
      for (final item in order.items) {
        final match = catalog.where((p) => p.name == item.name).firstOrNull;
        if (match != null) {
          await _ref.read(posCatalogProvider.notifier).restock(match.id, item.qty.toDouble());
        }
      }
      if (isUuid && isSupabaseReady) {
        await LocalPosStore.enqueueOutbox(
          _ref.read(activeMembershipProvider)!.storeId,
          {
            'id': const Uuid().v4(),
            'kind': 'void',
            'transactionId': order.id,
            'reason': reason,
          },
        );
        bumpOutboxTick(_ref);
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
            synced: o.synced,
          )
        else
          o,
    ];
    await _persistOrders();

    // Cash expected drops when a cash sale is voided.
    if (order.paymentMethod == PaymentMethod.cash) {
      await _ref.read(cashRegisterProvider.notifier).applyLocalCashSale(-order.total);
      try {
        await _ref.read(cashRegisterProvider.notifier).refresh();
      } catch (_) {}
    }
  }

  Future<void> refundSale({
    required PosOrder order,
    required List<({String? itemId, String name, int qty})> lines,
    String? reason,
  }) async {
    if (!order.canRefund) {
      throw StateError('This sale cannot be refunded.');
    }
    if (lines.isEmpty) {
      throw AppException('Select at least one item to refund.');
    }

    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(order.id);

    var refundAmount = 0.0;
    final online = isSupabaseReady && _ref.read(cloudReachableProvider);

    if (isUuid && online) {
      final result = await _repo.refundSale(
        transactionId: order.id,
        lines: lines,
        reason: reason,
      );
      refundAmount = result.refundAmount;
      await _ref.read(posCatalogProvider.notifier).restockVoidedLines(result.restock);
    } else {
      // Local / offline refund.
      for (final line in lines) {
        final match = order.items.where((i) {
          if (line.itemId != null && i.itemId != null) return i.itemId == line.itemId;
          return i.name == line.name;
        }).firstOrNull;
        if (match == null) continue;
        if (line.qty > match.refundableQty) {
          throw AppException('Cannot refund more than remaining for ${match.name}');
        }
        refundAmount += match.unitPrice * line.qty;
        final catalog = _ref.read(posCatalogProvider);
        final product = (match.productId != null
                ? catalog.where((p) => p.id == match.productId).firstOrNull
                : null) ??
            catalog.where((p) => p.name == match.name).firstOrNull;
        if (product != null) {
          await _ref.read(posCatalogProvider.notifier).restock(product.id, line.qty.toDouble());
        }
      }
    }

    state = [
      for (final o in state)
        if (o.id == order.id)
          () {
            final updatedItems = [
              for (final item in o.items)
                () {
                  final refundLine = lines.where((l) {
                    if (l.itemId != null && item.itemId != null) {
                      return l.itemId == item.itemId;
                    }
                    return l.name == item.name;
                  }).firstOrNull;
                  if (refundLine == null) return item;
                  return item.copyWith(refundedQty: item.refundedQty + refundLine.qty);
                }(),
            ];
            final nextRefunded = o.refundedTotal + refundAmount;
            final fully = updatedItems.every((i) => i.refundableQty <= 0);
            return PosOrder(
              id: o.id,
              orderNo: o.orderNo,
              items: updatedItems,
              subtotal: o.subtotal,
              tax: o.tax,
              total: o.total,
              paymentMethod: o.paymentMethod,
              timestampLabel: o.timestampLabel,
              createdAt: o.createdAt,
              status: fully ? 'Refunded' : 'Partial refund',
              synced: o.synced && online,
              refundedTotal: nextRefunded,
            );
          }()
        else
          o,
    ];
    await _persistOrders();

    if (order.paymentMethod == PaymentMethod.cash && refundAmount > 0) {
      await _ref.read(cashRegisterProvider.notifier).applyLocalCashSale(-refundAmount);
      if (online) {
        try {
          await _ref.read(cashRegisterProvider.notifier).refresh();
        } catch (_) {}
      }
    }
  }
}

enum VatMode { inclusive, plusTwelve }

class CheckoutSettings {
  const CheckoutSettings({
    this.paymentMethod = PaymentMethod.cash,
    this.vatMode = VatMode.inclusive,
    this.discountCode,
    this.discountKind,
    this.discountValue = 0,
  });

  final PaymentMethod paymentMethod;
  final VatMode vatMode;
  final String? discountCode;
  final DiscountKind? discountKind;
  final double discountValue;

  bool get hasDiscount =>
      discountCode != null &&
      discountCode!.isNotEmpty &&
      discountValue > 0 &&
      discountKind != null;

  CheckoutSettings copyWith({
    PaymentMethod? paymentMethod,
    VatMode? vatMode,
    String? discountCode,
    DiscountKind? discountKind,
    double? discountValue,
    bool clearDiscount = false,
  }) {
    return CheckoutSettings(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vatMode: vatMode ?? this.vatMode,
      discountCode: clearDiscount ? null : (discountCode ?? this.discountCode),
      discountKind: clearDiscount ? null : (discountKind ?? this.discountKind),
      discountValue: clearDiscount ? 0 : (discountValue ?? this.discountValue),
    );
  }
}

class CheckoutSettingsNotifier extends StateNotifier<CheckoutSettings> {
  CheckoutSettingsNotifier() : super(const CheckoutSettings());

  void setPayment(PaymentMethod m) => state = state.copyWith(paymentMethod: m);
  void setVat(VatMode m) => state = state.copyWith(vatMode: m);

  void applyDiscountCode(DiscountCode code) {
    state = state.copyWith(
      discountCode: code.code,
      discountKind: code.kind,
      discountValue: code.value,
    );
  }

  void clearDiscount() => state = state.copyWith(clearDiscount: true);

  /// Legacy percent-only helper (tests / chips). Prefer [applyDiscountCode].
  void setDiscount(double p) {
    if (p <= 0) {
      clearDiscount();
      return;
    }
    state = state.copyWith(
      discountCode: 'CUSTOM',
      discountKind: DiscountKind.percent,
      discountValue: p,
    );
  }
}

class DiscountCodesNotifier extends StateNotifier<List<DiscountCode>> {
  DiscountCodesNotifier(this._ref) : super(const []);

  final Ref _ref;
  final _repo = DiscountCodeRepository();
  String? _loadedStoreId;

  Future<void> loadForStore(String storeId) async {
    _loadedStoreId = storeId;
    final cached = await LocalPosStore.loadDiscountCodes(storeId);
    if (cached.isNotEmpty && mounted) {
      state = [for (final m in cached) DiscountCode.fromJson(m)];
    }

    if (!isSupabaseReady || !(_ref.read(cloudReachableProvider))) return;
    try {
      final codes = await _repo.listForStore(storeId);
      if (!mounted || _loadedStoreId != storeId) return;
      state = codes;
      await LocalPosStore.saveDiscountCodes(
        storeId,
        [for (final c in codes) c.toJson()],
      );
    } catch (_) {
      // Keep cached codes when cloud unavailable / table not migrated.
    }
  }

  Future<void> refresh() async {
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (storeId == null) return;
    await loadForStore(storeId);
  }

  Future<DiscountCode> upsert(DiscountCode code) async {
    final saved = await _repo.upsert(code);
    state = [
      saved,
      for (final c in state.where((c) => c.id != saved.id)) c,
    ];
    final storeId = saved.storeId;
    await LocalPosStore.saveDiscountCodes(
      storeId,
      [for (final c in state) c.toJson()],
    );
    return saved;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = [for (final c in state.where((c) => c.id != id)) c];
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (storeId != null) {
      await LocalPosStore.saveDiscountCodes(
        storeId,
        [for (final c in state) c.toJson()],
      );
    }
  }

  DiscountCode? findActiveCode(String raw) {
    final needle = raw.trim().toUpperCase();
    if (needle.isEmpty) return null;
    for (final c in state) {
      if (c.code == needle && c.isValidAt()) return c;
    }
    return null;
  }
}

final discountCodesProvider =
    StateNotifierProvider<DiscountCodesNotifier, List<DiscountCode>>(
  (ref) => DiscountCodesNotifier(ref),
);

/// Active (valid now) codes for cart chips.
final activeDiscountCodesProvider = Provider<List<DiscountCode>>((ref) {
  return ref.watch(discountCodesProvider).where((c) => c.isValidAt()).toList();
});

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

/// Product id that was just added — drives cart-row + card micro-animations.
final cartAddPulseProvider = StateProvider<String?>((ref) => null);

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
    if (storeId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    // Prefer cached open session when offline / backend unavailable.
    if (!isSupabaseReady || !(_ref.read(cloudReachableProvider))) {
      final cached = await _balanceFromCache(storeId);
      state = AsyncValue.data(cached);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repo.fetchOpenSession(storeId);
      if (session == null) {
        await LocalPosStore.clearRegister(storeId);
        return null;
      }
      final balance = await _repo.computeBalance(session);
      await _cacheBalance(storeId, balance);
      return balance;
    });

    // If cloud refresh failed, fall back to cache so selling can continue.
    if (state.hasError || state.valueOrNull == null) {
      final cached = await _balanceFromCache(storeId);
      if (cached != null) {
        state = AsyncValue.data(cached);
      }
    }
  }

  Future<void> applyLocalCashSale(double deltaTotal) async {
    final current = state.valueOrNull;
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (current == null || storeId == null) return;
    final next = RegisterBalance(
      session: current.session,
      cashSales: (current.cashSales + deltaTotal).clamp(0, double.infinity),
      payIns: current.payIns,
      payOuts: current.payOuts,
      expectedInDrawer: (current.expectedInDrawer + deltaTotal).clamp(0, double.infinity),
      movements: current.movements,
    );
    state = AsyncValue.data(next);
    await _cacheBalance(storeId, next);
  }

  Future<void> _cacheBalance(String storeId, RegisterBalance balance) async {
    await LocalPosStore.saveRegister(storeId, {
      'sessionId': balance.session.id,
      'storeId': balance.session.storeId,
      'branchId': balance.session.branchId,
      'openingFloat': balance.session.openingFloat,
      'openedAt': balance.session.openedAt.toIso8601String(),
      'status': balance.session.status,
      'cashSales': balance.cashSales,
      'payIns': balance.payIns,
      'payOuts': balance.payOuts,
      'expectedInDrawer': balance.expectedInDrawer,
    });
  }

  Future<RegisterBalance?> _balanceFromCache(String storeId) async {
    final raw = await LocalPosStore.loadRegister(storeId);
    if (raw == null) return null;
    if ((raw['status'] as String?) != 'open') return null;
    final openedAt = DateTime.tryParse(raw['openedAt'] as String? ?? '');
    if (openedAt == null) return null;
    final session = CashSession(
      id: raw['sessionId'] as String? ?? 'local-session',
      storeId: raw['storeId'] as String? ?? storeId,
      branchId: raw['branchId'] as String? ?? '',
      openingFloat: (raw['openingFloat'] as num?)?.toDouble() ?? 0,
      openedAt: openedAt,
      status: 'open',
    );
    return RegisterBalance(
      session: session,
      cashSales: (raw['cashSales'] as num?)?.toDouble() ?? 0,
      payIns: (raw['payIns'] as num?)?.toDouble() ?? 0,
      payOuts: (raw['payOuts'] as num?)?.toDouble() ?? 0,
      expectedInDrawer: (raw['expectedInDrawer'] as num?)?.toDouble() ?? 0,
      movements: const [],
    );
  }

  Future<void> claim({required String sessionId}) async {
    await _repo.claimSession(sessionId);
    await refresh();
  }

  Future<void> claimWithPin({
    required String sessionId,
    required String userId,
    required String pin,
  }) async {
    await _repo.claimSessionWithPin(
      sessionId: sessionId,
      userId: userId,
      pin: pin,
    );
    await refresh();
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
    final storeId = _ref.read(activeMembershipProvider)?.storeId;
    if (storeId != null) await LocalPosStore.clearRegister(storeId);
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
  var discount = 0.0;
  if (settings.hasDiscount) {
    if (settings.discountKind == DiscountKind.percent) {
      discount = gross * (settings.discountValue.clamp(0, 100) / 100);
    } else {
      discount = settings.discountValue.clamp(0, gross);
    }
  }
  discount = discount.clamp(0, gross);
  final afterDiscount = gross - discount;

  if (settings.vatMode == VatMode.inclusive) {
    return CartTotals(
      subtotal: afterDiscount,
      discount: discount,
      tax: 0,
      total: afterDiscount,
    );
  }

  final tax = afterDiscount * 0.12;
  return CartTotals(
    subtotal: afterDiscount,
    discount: discount,
    tax: tax,
    total: afterDiscount + tax,
  );
});

/// Keeps the customer-facing second screen in sync with the live cart.
final cartDisplaySyncProvider = Provider<void>((ref) {
  void publish() {
    final cart = ref.read(cartProvider);
    final totals = ref.read(cartTotalsProvider);
    final store = ref.read(activeMembershipProvider)?.store;
    publishCartDisplay(
      CartDisplaySnapshot(
        storeName: store?.name ?? 'CasinPOS',
        currencySymbol: store?.currencySymbol ?? '₱',
        lines: [
          for (final line in cart)
            CartDisplayLine(
              name: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.effectivePrice,
              lineTotal: line.lineTotal,
            ),
        ],
        subtotal: totals.subtotal,
        tax: totals.tax,
        total: totals.total,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  ref.listen(cartProvider, (_, _) => publish());
  ref.listen(cartTotalsProvider, (_, _) => publish());
  ref.listen(activeMembershipProvider, (_, _) => publish());
  publish();
});
