import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../bootstrap.dart';
import '../../domain/enums.dart';
import '../models/pos_models.dart';

class TransactionRepository {
  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) throw StateError('Supabase is not initialized.');
    return c;
  }

  Future<String> primaryBranchId(String storeId) async {
    final primary = await _client
        .from('branches')
        .select('id')
        .eq('store_id', storeId)
        .eq('is_primary', true)
        .maybeSingle();
    if (primary != null) return primary['id'] as String;

    final any = await _client
        .from('branches')
        .select('id')
        .eq('store_id', storeId)
        .limit(1)
        .maybeSingle();
    if (any == null) {
      throw StateError('No branch found for store.');
    }
    return any['id'] as String;
  }

  Future<List<PosOrder>> fetchRecentOrders(String storeId, {int limit = 200}) async {
    final rows = await _client
        .from('transactions')
        .select('*, transaction_items(*)')
        .eq('store_id', storeId)
        .inFilter('status', ['paid', 'voided', 'refunded'])
        .order('paid_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => _orderFromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Back-compat alias used by OrdersNotifier.
  Future<List<PosOrder>> fetchPaidOrders(String storeId, {int limit = 200}) =>
      fetchRecentOrders(storeId, limit: limit);

  Future<double> sumCashSalesSince({
    required String storeId,
    required DateTime since,
  }) async {
    final rows = await _client
        .from('transactions')
        .select('total, refunded_total')
        .eq('store_id', storeId)
        .eq('status', 'paid')
        .eq('payment_method', 'cash')
        .gte('paid_at', since.toUtc().toIso8601String());

    var sum = 0.0;
    for (final row in rows as List) {
      final m = row as Map;
      final t = m['total'];
      final r = m['refunded_total'];
      if (t is num) sum += t.toDouble() - ((r is num) ? r.toDouble() : 0);
    }
    return sum;
  }

  /// Refunds selected quantities. Returns restock lines + cash to remove from drawer.
  Future<({List<({String productId, double qty})> restock, double refundAmount})> refundSale({
    required String transactionId,
    required List<({String? itemId, String name, int qty})> lines,
    String? reason,
  }) async {
    if (lines.isEmpty) {
      throw StateError('Select at least one item to refund.');
    }

    final tx = await _client
        .from('transactions')
        .select('id, status, total, refunded_total, notes, transaction_items(*)')
        .eq('id', transactionId)
        .maybeSingle();
    if (tx == null) throw StateError('Sale not found.');
    final txMap = Map<String, dynamic>.from(tx);
    final status = txMap['status'] as String? ?? '';
    if (status != 'paid') {
      throw StateError('Only paid sales can be refunded.');
    }

    final itemsRaw = txMap['transaction_items'];
    if (itemsRaw is! List) throw StateError('Sale has no line items.');

    final byId = <String, Map<String, dynamic>>{};
    final byName = <String, Map<String, dynamic>>{};
    for (final raw in itemsRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id'] as String?;
      if (id != null) byId[id] = m;
      final name = m['name_snapshot'] as String? ?? '';
      byName[name] = m;
    }

    var refundAmount = 0.0;
    final restock = <({String productId, double qty})>[];

    for (final line in lines) {
      if (line.qty <= 0) continue;
      final row = (line.itemId != null ? byId[line.itemId!] : null) ?? byName[line.name];
      if (row == null) {
        throw StateError('Item "${line.name}" not found on this sale.');
      }
      final qty = ((row['quantity'] as num?) ?? 0).toDouble();
      final already = ((row['refunded_quantity'] as num?) ?? 0).toDouble();
      final remaining = qty - already;
      if (line.qty > remaining + 0.0001) {
        throw StateError('Cannot refund more than remaining for ${line.name}.');
      }
      final unit = ((row['unit_price'] as num?) ?? 0).toDouble();
      final nextRefunded = already + line.qty;
      await _client.from('transaction_items').update({
        'refunded_quantity': nextRefunded,
      }).eq('id', row['id'] as String);

      refundAmount += unit * line.qty;
      final pid = row['product_id'] as String?;
      if (pid != null && pid.isNotEmpty) {
        restock.add((productId: pid, qty: line.qty.toDouble()));
      }
    }

    final prevRefunded = ((txMap['refunded_total'] as num?) ?? 0).toDouble();
    final total = ((txMap['total'] as num?) ?? 0).toDouble();
    final nextRefundedTotal = prevRefunded + refundAmount;
    final fully = nextRefundedTotal >= total - 0.009;

    final noteParts = <String>[
      if ((txMap['notes'] as String?)?.trim().isNotEmpty == true) (txMap['notes'] as String).trim(),
      if (reason != null && reason.trim().isNotEmpty) 'Refund: ${reason.trim()}',
      'Refunded ₱${refundAmount.toStringAsFixed(2)}',
    ];

    await _client.from('transactions').update({
      'refunded_total': nextRefundedTotal,
      if (fully) 'status': 'refunded',
      'notes': noteParts.join(' · '),
    }).eq('id', transactionId);

    return (restock: restock, refundAmount: refundAmount);
  }

  /// Marks a paid sale as voided and returns inventory lines to restock.
  Future<List<({String productId, double qty})>> voidSale({
    required String transactionId,
    String? reason,
  }) async {
    final items = await _client
        .from('transaction_items')
        .select('product_id, quantity')
        .eq('transaction_id', transactionId);

    final updated = await _client
        .from('transactions')
        .update({
          'status': 'voided',
          if (reason != null && reason.trim().isNotEmpty) 'notes': reason.trim(),
        })
        .eq('id', transactionId)
        .eq('status', 'paid')
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError('Sale could not be voided (already voided or missing).');
    }

    final restock = <({String productId, double qty})>[];
    for (final raw in items as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final pid = m['product_id'] as String?;
      if (pid == null || pid.isEmpty) continue;
      final qty = ((m['quantity'] as num?) ?? 0).toDouble();
      if (qty > 0) restock.add((productId: pid, qty: qty));
    }
    return restock;
  }

  Future<PosOrder> createPaidSale({
    required String storeId,
    required BusinessType businessType,
    required List<CartLine> lines,
    required double subtotal,
    required double tax,
    required double total,
    required PaymentMethod paymentMethod,
    required double cashReceived,
    required double changeGiven,
    required String currencyCode,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');

    final branchId = await primaryBranchId(storeId);
    final id = const Uuid().v4();
    final orderNo = '#CP-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final now = DateTime.now().toUtc();

    await _client.from('transactions').insert({
      'id': id,
      'store_id': storeId,
      'branch_id': branchId,
      'order_no': orderNo,
      'business_type': businessType.value,
      'status': 'paid',
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'currency_code': currencyCode,
      'payment_method': paymentMethod.name,
      'cash_received': paymentMethod == PaymentMethod.cash ? cashReceived : null,
      'change_given': paymentMethod == PaymentMethod.cash ? changeGiven : null,
      'staff_id': uid,
      'paid_at': now.toIso8601String(),
    });

    if (lines.isNotEmpty) {
      await _client.from('transaction_items').insert([
        for (final line in lines)
          {
            'transaction_id': id,
            'product_id': _isUuid(line.product.id) ? line.product.id : null,
            'name_snapshot': line.product.name,
            'quantity': line.quantity,
            'unit_price': line.product.price,
            'line_total': line.lineTotal,
            'additions': [],
          },
      ]);
    }

    return PosOrder(
      id: id,
      orderNo: orderNo,
      items: [
        for (final l in lines)
          OrderLine(
            name: l.product.name,
            qty: l.quantity,
            unitPrice: l.product.price,
            category: l.product.category,
            productId: l.product.id,
          ),
      ],
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      timestampLabel: 'Just now',
      createdAt: now.toLocal(),
    );
  }

  PosOrder _orderFromRow(Map<String, dynamic> json) {
    final itemsRaw = json['transaction_items'];
    final items = <OrderLine>[];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final qty = ((m['quantity'] as num?) ?? 1).round();
        final refunded = ((m['refunded_quantity'] as num?) ?? 0).round();
        items.add(
          OrderLine(
            name: m['name_snapshot'] as String? ?? 'Item',
            qty: qty,
            unitPrice: ((m['unit_price'] as num?) ?? 0).toDouble(),
            category: 'General',
            productId: m['product_id'] as String?,
            refundedQty: refunded,
            itemId: m['id'] as String?,
          ),
        );
      }
    }

    final paidAt = json['paid_at'] != null
        ? DateTime.parse(json['paid_at'] as String).toLocal()
        : DateTime.parse(json['created_at'] as String).toLocal();

    final methodRaw = json['payment_method'] as String? ?? 'cash';
    final method = PaymentMethod.values.firstWhere(
      (m) => m.name == methodRaw,
      orElse: () => PaymentMethod.cash,
    );

    final refundedTotal = ((json['refunded_total'] as num?) ?? 0).toDouble();
    final statusRaw = json['status'] as String?;
    var status = _statusLabel(statusRaw);
    if (statusRaw == 'paid' && refundedTotal > 0) {
      final allRefunded = items.isNotEmpty && items.every((i) => i.refundableQty <= 0);
      status = allRefunded ? 'Refunded' : 'Partial refund';
    }

    return PosOrder(
      id: json['id'] as String,
      orderNo: json['order_no'] as String,
      items: items,
      subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
      tax: ((json['tax'] as num?) ?? 0).toDouble(),
      total: ((json['total'] as num?) ?? 0).toDouble(),
      paymentMethod: method,
      timestampLabel: DateFormat('MMM d · h:mm a').format(paidAt),
      createdAt: paidAt,
      status: status,
      refundedTotal: refundedTotal,
    );
  }

  String _statusLabel(String? raw) {
    switch (raw) {
      case 'voided':
        return 'Voided';
      case 'refunded':
        return 'Refunded';
      case 'paid':
      default:
        return 'Paid';
    }
  }

  bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);
}
