import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import 'transaction_repository.dart';

class CashSession {
  const CashSession({
    required this.id,
    required this.storeId,
    required this.branchId,
    required this.openingFloat,
    required this.openedAt,
    required this.status,
    this.closingCount,
    this.expectedCash,
    this.variance,
    this.notes,
    this.closedAt,
    this.claimedBy,
    this.claimedAt,
    this.openedBy,
  });

  final String id;
  final String storeId;
  final String branchId;
  final double openingFloat;
  final DateTime openedAt;
  final String status;
  final double? closingCount;
  final double? expectedCash;
  final double? variance;
  final String? notes;
  final DateTime? closedAt;
  final String? claimedBy;
  final DateTime? claimedAt;
  final String? openedBy;

  bool get isOpen => status == 'open';

  factory CashSession.fromJson(Map<String, dynamic> json) {
    return CashSession(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      branchId: json['branch_id'] as String,
      openingFloat: ((json['opening_float'] as num?) ?? 0).toDouble(),
      openedAt: DateTime.parse(json['opened_at'] as String).toLocal(),
      status: json['status'] as String? ?? 'open',
      closingCount: (json['closing_count'] as num?)?.toDouble(),
      expectedCash: (json['expected_cash'] as num?)?.toDouble(),
      variance: (json['variance'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String).toLocal()
          : null,
      claimedBy: json['claimed_by'] as String?,
      claimedAt: json['claimed_at'] != null
          ? DateTime.parse(json['claimed_at'] as String).toLocal()
          : null,
      openedBy: json['opened_by'] as String?,
    );
  }
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.kind,
    required this.amount,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String kind; // pay_in | pay_out
  final double amount;
  final DateTime createdAt;
  final String? note;

  factory CashMovement.fromJson(Map<String, dynamic> json) {
    return CashMovement(
      id: json['id'] as String,
      kind: json['kind'] as String,
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class RegisterBalance {
  const RegisterBalance({
    required this.session,
    required this.cashSales,
    required this.payIns,
    required this.payOuts,
    required this.expectedInDrawer,
    required this.movements,
  });

  final CashSession session;
  final double cashSales;
  final double payIns;
  final double payOuts;
  final double expectedInDrawer;
  final List<CashMovement> movements;
}

class CashRegisterRepository {
  CashRegisterRepository(this._transactions);

  final TransactionRepository _transactions;

  SupabaseClient get _client {
    final c = supabaseOrNull;
    if (c == null) throw StateError('Supabase is not initialized.');
    return c;
  }

  Future<CashSession?> fetchOpenSession(String storeId) async {
    final row = await _client
        .from('cash_sessions')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'open')
        .maybeSingle();
    if (row == null) return null;
    return CashSession.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<CashSession>> fetchRecentSessions(String storeId, {int limit = 20}) async {
    final rows = await _client
        .from('cash_sessions')
        .select()
        .eq('store_id', storeId)
        .order('opened_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => CashSession.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CashSession> openSession({
    required String storeId,
    required double openingFloat,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    final existing = await fetchOpenSession(storeId);
    if (existing != null) {
      throw StateError('A register session is already open.');
    }
    final branchId = await _transactions.primaryBranchId(storeId);
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from('cash_sessions')
        .insert({
          'store_id': storeId,
          'branch_id': branchId,
          'opened_by': uid,
          'claimed_by': uid,
          'claimed_at': now,
          'opening_float': openingFloat,
          'notes': notes,
          'status': 'open',
        })
        .select()
        .single();
    return CashSession.fromJson(Map<String, dynamic>.from(row));
  }

  /// Assigns the open shift to the signed-in cashier for accountability.
  Future<CashSession> claimSession(String sessionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    final row = await _client
        .from('cash_sessions')
        .update({
          'claimed_by': uid,
          'claimed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('status', 'open')
        .select()
        .single();
    return CashSession.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<CashMovement>> fetchMovements(String sessionId) async {
    final rows = await _client
        .from('cash_movements')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => CashMovement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addMovement({
    required String sessionId,
    required String kind,
    required double amount,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    await _client.from('cash_movements').insert({
      'session_id': sessionId,
      'kind': kind,
      'amount': amount,
      'note': note,
      'created_by': uid,
    });
  }

  Future<RegisterBalance> computeBalance(CashSession session) async {
    final cashSales = await _transactions.sumCashSalesSince(
      storeId: session.storeId,
      since: session.openedAt,
    );
    final movements = await fetchMovements(session.id);
    var payIns = 0.0;
    var payOuts = 0.0;
    for (final m in movements) {
      if (m.kind == 'pay_in') {
        payIns += m.amount;
      } else {
        payOuts += m.amount;
      }
    }
    final expected = session.openingFloat + cashSales + payIns - payOuts;
    return RegisterBalance(
      session: session,
      cashSales: cashSales,
      payIns: payIns,
      payOuts: payOuts,
      expectedInDrawer: expected,
      movements: movements,
    );
  }

  Future<CashSession> closeSession({
    required CashSession session,
    required double closingCount,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    final balance = await computeBalance(session);
    final variance = closingCount - balance.expectedInDrawer;
    final row = await _client
        .from('cash_sessions')
        .update({
          'status': 'closed',
          'closed_by': uid,
          'closed_at': DateTime.now().toUtc().toIso8601String(),
          'closing_count': closingCount,
          'expected_cash': balance.expectedInDrawer,
          'variance': variance,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .eq('id', session.id)
        .select()
        .single();
    return CashSession.fromJson(Map<String, dynamic>.from(row));
  }
}
