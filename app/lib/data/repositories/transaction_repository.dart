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
        .inFilter('status', ['paid', 'voided'])
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
        .select('total')
        .eq('store_id', storeId)
        .eq('status', 'paid')
        .eq('payment_method', 'cash')
        .gte('paid_at', since.toUtc().toIso8601String());

    var sum = 0.0;
    for (final row in rows as List) {
      final t = (row as Map)['total'];
      if (t is num) sum += t.toDouble();
    }
    return sum;
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
    final orderNo = '#FP-${DateTime.now().millisecondsSinceEpoch % 1000000}';
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
      createdAt: now.toLocal(),
    );
  }

  PosOrder _orderFromRow(Map<String, dynamic> json) {
    final itemsRaw = json['transaction_items'];
    final items = <({String name, int qty, double unitPrice, String category})>[];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        final m = Map<String, dynamic>.from(raw as Map);
        items.add((
          name: m['name_snapshot'] as String? ?? 'Item',
          qty: ((m['quantity'] as num?) ?? 1).round(),
          unitPrice: ((m['unit_price'] as num?) ?? 0).toDouble(),
          category: 'General',
        ));
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
      status: _statusLabel(json['status'] as String?),
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
