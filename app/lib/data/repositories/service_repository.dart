import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../bootstrap.dart';
import '../../core/errors/app_errors.dart';
import '../../domain/enums.dart';
import '../models/pos_models.dart';
import '../models/service_models.dart';

class ServiceRepository {
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
    if (any == null) throw StateError('No branch found for store.');
    return any['id'] as String;
  }

  Future<List<ServiceCustomer>> listCustomers(String storeId) async {
    final rows = await _client
        .from('service_customers')
        .select()
        .eq('store_id', storeId)
        .order('last_seen_at', ascending: false);
    return (rows as List)
        .map((e) => ServiceCustomer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServiceCustomer> upsertCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
  }) async {
    final map = await _rpcMap('upsert_service_customer', {
      'p_store_id': storeId,
      'p_name': name,
      'p_phone': phone,
      'p_email': email,
    });
    final id = map['id'] as String?;
    if (id == null) {
      return ServiceCustomer(id: '', storeId: storeId, name: name, phone: phone, email: email);
    }
    return ServiceCustomer(
      id: id,
      storeId: storeId,
      name: map['name'] as String? ?? name,
      phone: map['phone'] as String? ?? phone,
      email: map['email'] as String? ?? email,
    );
  }

  Future<void> rememberCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
  }) async {
    if (name.trim().isEmpty) return;
    try {
      await upsertCustomer(
        storeId: storeId,
        name: name,
        phone: phone,
        email: email,
      );
    } catch (_) {
      // Don't block quote/booking if the client save fails.
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('service_customers').delete().eq('id', id);
  }

  Future<List<ServiceOffering>> listServices(String storeId) async {
    final rows = await _client
        .from('services')
        .select()
        .eq('store_id', storeId)
        .order('name');
    return (rows as List)
        .map((e) => ServiceOffering.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServiceOffering> upsertService({
    required String storeId,
    String? id,
    required String name,
    String? description,
    required int durationMinutes,
    required double price,
    bool isActive = true,
  }) async {
    final payload = {
      'id': id ?? const Uuid().v4(),
      'store_id': storeId,
      'name': name.trim(),
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'duration_minutes': durationMinutes,
      'price': price,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _client.from('services').upsert(payload).select().single();
    return ServiceOffering.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteService(String id) async {
    await _client.from('services').delete().eq('id', id);
  }

  Future<List<ServiceQuote>> listQuotes(String storeId) async {
    final rows = await _client
        .from('quotes')
        .select('*, quote_line_items(*)')
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => ServiceQuote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServiceQuote> saveQuote({
    required String storeId,
    required String branchId,
    required String createdBy,
    String? id,
    required String clientName,
    String? clientPhone,
    String? clientEmail,
    String? jobDescription,
    DateTime? validUntil,
    required List<QuoteLineDraft> lines,
    QuoteStatus status = QuoteStatus.draft,
  }) async {
    final quoteId = id ?? const Uuid().v4();
    final total = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    final payload = <String, dynamic>{
      'id': quoteId,
      'store_id': storeId,
      'branch_id': branchId,
      'client_name': clientName.trim(),
      'client_phone': clientPhone?.trim(),
      'client_email': clientEmail?.trim(),
      'job_description': jobDescription?.trim(),
      'estimated_total': total,
      'status': status.value,
      'valid_until': validUntil?.toIso8601String().split('T').first,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      payload['created_by'] = createdBy;
      await _client.from('quotes').insert(payload);
    } else {
      payload.remove('id');
      await _client.from('quotes').update(payload).eq('id', quoteId);
    }
    await _client.from('quote_line_items').delete().eq('quote_id', quoteId);
    if (lines.isNotEmpty) {
      await _client.from('quote_line_items').insert([
        for (var i = 0; i < lines.length; i++)
          {
            'quote_id': quoteId,
            'sort_order': i,
            'description': lines[i].description.trim(),
            'quantity': lines[i].quantity,
            'unit_price': lines[i].unitPrice,
          },
      ]);
    }
    final row = await _client
        .from('quotes')
        .select('*, quote_line_items(*)')
        .eq('id', quoteId)
        .single();
    await rememberCustomer(
      storeId: storeId,
      name: clientName,
      phone: clientPhone,
      email: clientEmail,
    );
    return ServiceQuote.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> rejectQuote(String quoteId) async {
    await _client.from('quotes').update({
      'status': QuoteStatus.rejected.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', quoteId).inFilter('status', ['draft', 'sent']);
  }

  Future<Map<String, dynamic>> sendQuote(String quoteId) async {
    return _rpcMap('send_service_quote', {'p_quote_id': quoteId});
  }

  Future<Map<String, dynamic>> acceptQuote({
    required String quoteId,
    required DateTime scheduledAt,
    double depositAmount = 0,
    PaymentMethod? paymentMethod,
  }) async {
    return _rpcMap('accept_service_quote', {
      'p_quote_id': quoteId,
      'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'p_deposit_amount': depositAmount,
      'p_payment_method': paymentMethod?.name,
    });
  }

  Future<List<ServiceBooking>> listBookings(String storeId) async {
    final rows = await _client
        .from('service_bookings')
        .select('*, service_booking_items(*)')
        .eq('store_id', storeId)
        .order('scheduled_at');
    final maps = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final txnIds = maps
        .map((m) => m['transaction_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (txnIds.isNotEmpty) {
      final txns = await _client
          .from('transactions')
          .select('id, amount_paid, balance_due, payment_state, total')
          .inFilter('id', txnIds);
      final byId = <String, Map<String, dynamic>>{
        for (final raw in txns as List)
          if (raw is Map && raw['id'] is String)
            raw['id'] as String: Map<String, dynamic>.from(raw),
      };
      for (final m in maps) {
        final id = m['transaction_id'] as String?;
        if (id != null && byId.containsKey(id)) {
          m['transactions'] = byId[id];
        }
      }
    }
    return maps.map(ServiceBooking.fromJson).toList();
  }

  Future<Map<String, dynamic>> createCatalogBooking({
    required String storeId,
    required String clientName,
    String? clientPhone,
    required DateTime scheduledAt,
    required List<Map<String, dynamic>> items,
    double depositAmount = 0,
    PaymentMethod? paymentMethod,
    String? notes,
  }) async {
    final result = await _rpcMap('create_catalog_service_booking', {
      'p_store_id': storeId,
      'p_client_name': clientName,
      'p_client_phone': clientPhone,
      'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'p_items': items,
      'p_deposit_amount': depositAmount,
      'p_payment_method': paymentMethod?.name,
      'p_notes': notes,
    });
    await rememberCustomer(
      storeId: storeId,
      name: clientName,
      phone: clientPhone,
    );
    return result;
  }

  Future<Map<String, dynamic>> collectPayment({
    required String bookingId,
    required double amount,
    required PaymentMethod paymentMethod,
  }) async {
    return _rpcMap('collect_service_payment', {
      'p_booking_id': bookingId,
      'p_amount': amount,
      'p_payment_method': paymentMethod.name,
    });
  }

  Future<void> setBookingStatus({
    required String bookingId,
    required ServiceBookingStatus status,
  }) async {
    try {
      await _client.rpc('set_service_booking_status', params: {
        'p_booking_id': bookingId,
        'p_status': status.value,
      });
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ?? 'Could not update booking.',
        cause: e,
      );
    }
  }

  Future<ServiceReportStats> reportStats({
    required String storeId,
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) async {
    final map = await _rpcMap('report_service_stats', {
      'p_store_id': storeId,
      'p_start': start.toUtc().toIso8601String(),
      'p_end': end.toUtc().toIso8601String(),
      if (branchId != null) 'p_branch_id': branchId,
    });
    return ServiceReportStats.fromJson(map);
  }

  Future<Map<String, dynamic>> _rpcMap(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc(name, params: params);
      if (result is Map) return Map<String, dynamic>.from(result);
      if (result is String) {
        final decoded = jsonDecode(result);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
      throw AppException('Could not load report.');
    } on PostgrestException catch (e) {
      throw AppException(
        mapKnownBackendError(e.message) ??
            mapKnownBackendError(e.toString()) ??
            'Could not complete that action.',
        cause: e,
      );
    }
  }
}
