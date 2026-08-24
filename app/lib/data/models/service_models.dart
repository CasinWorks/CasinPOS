import '../../domain/enums.dart';

class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    this.description,
    this.durationMinutes = 60,
    this.isActive = true,
    this.categoryId,
  });

  final String id;
  final String storeId;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price;
  final bool isActive;
  final String? categoryId;

  factory ServiceOffering.fromJson(Map<String, dynamic> json) => ServiceOffering(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        categoryId: json['category_id'] as String?,
      );
}

class ServiceCustomer {
  const ServiceCustomer({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.lastSeenAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime? lastSeenAt;

  String get subtitle {
    final parts = [phone, email].where((e) => e != null && e.trim().isNotEmpty);
    return parts.join(' · ');
  }

  factory ServiceCustomer.fromJson(Map<String, dynamic> json) => ServiceCustomer(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        notes: json['notes'] as String?,
        lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      );
}

class QuoteLineDraft {
  QuoteLineDraft({
    this.description = '',
    this.quantity = 1,
    this.unitPrice = 0,
  });

  String description;
  double quantity;
  double unitPrice;

  double get lineTotal => quantity * unitPrice;
}

class QuoteLineItem {
  const QuoteLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.sortOrder = 0,
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final int sortOrder;

  double get lineTotal => quantity * unitPrice;

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) => QuoteLineItem(
        id: json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class ServiceQuote {
  const ServiceQuote({
    required this.id,
    required this.storeId,
    required this.clientName,
    required this.estimatedTotal,
    required this.status,
    this.clientPhone,
    this.clientEmail,
    this.jobDescription,
    this.validUntil,
    this.shareToken,
    this.sentAt,
    this.acceptedAt,
    this.acceptedBookingId,
    this.createdAt,
    this.lines = const [],
  });

  final String id;
  final String storeId;
  final String clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? jobDescription;
  final double estimatedTotal;
  final QuoteStatus status;
  final DateTime? validUntil;
  final String? shareToken;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final String? acceptedBookingId;
  final DateTime? createdAt;
  final List<QuoteLineItem> lines;

  bool get isExpired {
    if (validUntil == null) return false;
    if (status != QuoteStatus.draft && status != QuoteStatus.sent) return false;
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    final until = DateTime(validUntil!.year, validUntil!.month, validUntil!.day);
    return until.isBefore(d);
  }

  factory ServiceQuote.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['quote_line_items'];
    final lines = <QuoteLineItem>[];
    if (linesRaw is List) {
      for (final raw in linesRaw) {
        if (raw is Map) {
          lines.add(QuoteLineItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      lines.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    DateTime? parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ServiceQuote(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      clientName: json['client_name'] as String? ?? '',
      clientPhone: json['client_phone'] as String?,
      clientEmail: json['client_email'] as String?,
      jobDescription: json['job_description'] as String?,
      estimatedTotal: (json['estimated_total'] as num?)?.toDouble() ?? 0,
      status: QuoteStatus.fromValue(json['status'] as String? ?? 'draft'),
      validUntil: parseDate(json['valid_until']),
      shareToken: json['share_token'] as String?,
      sentAt: parseDate(json['sent_at']),
      acceptedAt: parseDate(json['accepted_at']),
      acceptedBookingId: json['accepted_booking_id'] as String?,
      createdAt: parseDate(json['created_at']),
      lines: lines,
    );
  }
}

class ServiceBookingItem {
  const ServiceBookingItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.serviceId,
  });

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final String? serviceId;

  double get lineTotal => quantity * unitPrice;

  factory ServiceBookingItem.fromJson(Map<String, dynamic> json) =>
      ServiceBookingItem(
        id: json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        serviceId: json['service_id'] as String?,
      );
}

class ServiceBooking {
  const ServiceBooking({
    required this.id,
    required this.storeId,
    required this.clientName,
    required this.scheduledAt,
    required this.status,
    this.clientPhone,
    this.quoteId,
    this.notes,
    this.transactionId,
    this.items = const [],
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.paymentState = PaymentState.unpaid,
    this.txnTotal = 0,
  });

  final String id;
  final String storeId;
  final String? quoteId;
  final String clientName;
  final String? clientPhone;
  final DateTime scheduledAt;
  final ServiceBookingStatus status;
  final String? notes;
  final String? transactionId;
  final List<ServiceBookingItem> items;
  final double amountPaid;
  final double balanceDue;
  final PaymentState paymentState;
  final double txnTotal;

  double get itemsTotal =>
      items.fold(0, (sum, i) => sum + i.lineTotal);

  factory ServiceBooking.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['service_booking_items'];
    final items = <ServiceBookingItem>[];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        if (raw is Map) {
          items.add(ServiceBookingItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    final txn = json['transactions'];
    Map<String, dynamic>? txnMap;
    if (txn is Map) {
      txnMap = Map<String, dynamic>.from(txn);
    } else if (txn is List && txn.isNotEmpty && txn.first is Map) {
      txnMap = Map<String, dynamic>.from(txn.first as Map);
    }

    return ServiceBooking(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      quoteId: json['quote_id'] as String?,
      clientName: json['client_name'] as String? ?? '',
      clientPhone: json['client_phone'] as String?,
      scheduledAt: DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
          DateTime.now(),
      status: ServiceBookingStatus.fromValue(json['status'] as String? ?? 'upcoming'),
      notes: json['notes'] as String?,
      transactionId: json['transaction_id'] as String?,
      items: items,
      amountPaid: (txnMap?['amount_paid'] as num?)?.toDouble() ?? 0,
      balanceDue: (txnMap?['balance_due'] as num?)?.toDouble() ??
          (txnMap == null
              ? items.fold(0.0, (s, i) => s + i.lineTotal)
              : 0),
      paymentState: PaymentState.fromValue(
        txnMap?['payment_state'] as String? ?? 'unpaid',
      ),
      txnTotal: (txnMap?['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ServiceReportStats {
  const ServiceReportStats({
    required this.quotesSent,
    required this.quotesAccepted,
    required this.conversionRate,
    required this.averageQuoteValue,
    required this.outstandingQuotes,
    required this.upcomingBookings,
    required this.completedBookings,
    required this.outstandingDeposits,
    this.collectedRevenue = 0,
    this.paidJobs = 0,
    this.revenueByService = const [],
  });

  final int quotesSent;
  final int quotesAccepted;
  final double conversionRate;
  final double averageQuoteValue;
  final int outstandingQuotes;
  final int upcomingBookings;
  final int completedBookings;
  final double outstandingDeposits;
  final double collectedRevenue;
  final int paidJobs;
  final List<({String name, double units, double revenue})> revenueByService;

  factory ServiceReportStats.fromJson(Map<String, dynamic> json) {
    final by = <({String name, double units, double revenue})>[];
    final raw = json['revenue_by_service'];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        by.add((
          name: m['item_name'] as String? ?? '',
          units: (m['units_sold'] as num?)?.toDouble() ?? 0,
          revenue: (m['revenue'] as num?)?.toDouble() ?? 0,
        ));
      }
    }
    return ServiceReportStats(
      quotesSent: (json['quotes_sent'] as num?)?.toInt() ?? 0,
      quotesAccepted: (json['quotes_accepted'] as num?)?.toInt() ?? 0,
      conversionRate: (json['conversion_rate'] as num?)?.toDouble() ?? 0,
      averageQuoteValue: (json['average_quote_value'] as num?)?.toDouble() ?? 0,
      outstandingQuotes: (json['outstanding_quotes'] as num?)?.toInt() ?? 0,
      upcomingBookings: (json['upcoming_bookings'] as num?)?.toInt() ?? 0,
      completedBookings: (json['completed_bookings'] as num?)?.toInt() ?? 0,
      outstandingDeposits: (json['outstanding_deposits'] as num?)?.toDouble() ?? 0,
      collectedRevenue: (json['collected_revenue'] as num?)?.toDouble() ?? 0,
      paidJobs: (json['paid_jobs'] as num?)?.toInt() ?? 0,
      revenueByService: by,
    );
  }
}
