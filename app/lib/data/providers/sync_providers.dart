import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../domain/enums.dart';
import '../local/local_pos_store.dart';
import '../models/pos_models.dart';
import '../repositories/product_repository.dart';
import '../repositories/transaction_repository.dart';
import 'connectivity_providers.dart';
import 'outbox_tick.dart';
import 'pos_providers.dart';
import 'session_providers.dart';

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(outboxTickProvider);
  final storeId = ref.watch(activeMembershipProvider)?.storeId;
  if (storeId == null) return 0;
  return (await LocalPosStore.loadOutbox(storeId)).length;
});

/// Flushes the on-device outbox when cloud is reachable.
class SyncOutboxService {
  SyncOutboxService(this._ref);

  final Ref _ref;

  TransactionRepository get _tx => _ref.read(transactionRepositoryProvider);
  ProductRepository get _products => _ref.read(productRepositoryProvider);

  Future<void> flush() async {
    if (!isSupabaseReady) return;
    if (!(_ref.read(cloudReachableProvider))) return;
    final membership = _ref.read(activeMembershipProvider);
    final storeId = membership?.storeId;
    if (storeId == null || membership == null) return;

    final items = [...await LocalPosStore.loadOutbox(storeId)];
    if (items.isEmpty) {
      bumpOutboxTick(_ref);
      return;
    }

    for (final item in items) {
      final id = item['id'] as String?;
      final kind = item['kind'] as String?;
      if (id == null || kind == null) continue;
      try {
        switch (kind) {
          case 'sale':
            await _flushSale(membership.storeId, membership.store.businessType, item);
          case 'stock':
            final productId = item['productId'] as String?;
            final stock = (item['stock'] as num?)?.toDouble();
            if (productId != null && stock != null) {
              await _products.updateStock(productId: productId, stock: stock);
            }
          case 'void':
            final txId = item['transactionId'] as String?;
            if (txId != null) {
              await _tx.voidSale(
                transactionId: txId,
                reason: item['reason'] as String?,
              );
            }
          default:
            break;
        }
        await LocalPosStore.removeOutboxId(storeId, id);
        bumpOutboxTick(_ref);
      } catch (_) {
        // Preserve outbox order; retry after next reconnect.
        break;
      }
    }

    try {
      await _ref.read(cashRegisterProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _flushSale(
    String storeId,
    BusinessType businessType,
    Map<String, dynamic> item,
  ) async {
    final linesRaw = item['lines'];
    if (linesRaw is! List) return;
    final lines = <CartLine>[];
    for (final raw in linesRaw.whereType<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      final productMap = m['product'];
      if (productMap is! Map) continue;
      final product = RetailProduct.fromJson(Map<String, dynamic>.from(productMap));
      final qty = (m['quantity'] as num?)?.round() ?? 1;
      if (product.id.isEmpty) continue;
      lines.add(CartLine(product: product, quantity: qty));
    }
    if (lines.isEmpty) return;

    final methodRaw = item['paymentMethod'] as String? ?? 'cash';
    final method = PaymentMethod.values.firstWhere(
      (m) => m.name == methodRaw,
      orElse: () => PaymentMethod.cash,
    );

    final remote = await _tx.createPaidSale(
      storeId: storeId,
      businessType: businessType,
      lines: lines,
      subtotal: (item['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (item['tax'] as num?)?.toDouble() ?? 0,
      total: (item['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: method,
      cashReceived: (item['cashReceived'] as num?)?.toDouble() ?? 0,
      changeGiven: (item['changeGiven'] as num?)?.toDouble() ?? 0,
      currencyCode: item['currencyCode'] as String? ?? 'PHP',
    );

    final localId = item['localOrderId'] as String? ?? item['id'] as String?;
    if (localId != null) {
      _ref.read(ordersProvider.notifier).replaceLocalWithRemote(localId, remote);
    }

    for (final line in lines) {
      final live =
          _ref.read(posCatalogProvider).where((p) => p.id == line.product.id).firstOrNull;
      if (live != null) {
        await _products.updateStock(productId: live.id, stock: live.stock);
      }
    }
  }
}

final syncOutboxServiceProvider = Provider<SyncOutboxService>(
  (ref) => SyncOutboxService(ref),
);

/// Boots connectivity listener so reconnect triggers outbox flush.
final syncBootstrapProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(connectivityOnlineProvider, (prev, next) {
    final online = next.valueOrNull ?? false;
    if (online) {
      unawaited(ref.read(syncOutboxServiceProvider).flush());
    }
  });
});
