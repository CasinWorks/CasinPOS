import '../../domain/enums.dart';

class PlatformTenant {
  const PlatformTenant({
    required this.id,
    required this.name,
    required this.businessType,
    required this.planTier,
    required this.transactionsThisPeriod,
    required this.monthlyTransactionLimit,
    required this.createdAt,
    this.billingPeriodStart,
    this.suspendedAt,
    this.suspensionReason,
    this.updatedAt,
    this.ownerId,
    this.ownerEmail,
    this.ownerName,
    this.activeMembers = 0,
    this.subscriptionStatus,
  });

  final String id;
  final String name;
  final BusinessType businessType;
  final PlanTier planTier;
  final int transactionsThisPeriod;
  final int monthlyTransactionLimit;
  final DateTime createdAt;
  final DateTime? billingPeriodStart;
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final DateTime? updatedAt;
  final String? ownerId;
  final String? ownerEmail;
  final String? ownerName;
  final int activeMembers;
  final String? subscriptionStatus;

  bool get isSuspended => suspendedAt != null;

  double get usageRatio {
    if (monthlyTransactionLimit <= 0) return 0;
    return (transactionsThisPeriod / monthlyTransactionLimit).clamp(0, 2);
  }

  factory PlatformTenant.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return PlatformTenant(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Store',
      businessType: BusinessType.fromValue(json['business_type'] as String? ?? 'retail'),
      planTier: PlanTier.fromValue(json['plan_tier'] as String? ?? 'free'),
      transactionsThisPeriod: (json['transactions_this_period'] as num?)?.toInt() ?? 0,
      monthlyTransactionLimit: (json['monthly_transaction_limit'] as num?)?.toInt() ?? 1000,
      createdAt: parseTs(json['created_at']) ?? DateTime.now(),
      billingPeriodStart: parseTs(json['billing_period_start']),
      suspendedAt: parseTs(json['suspended_at']),
      suspensionReason: json['suspension_reason'] as String?,
      updatedAt: parseTs(json['updated_at']),
      ownerId: json['owner_id'] as String?,
      ownerEmail: json['owner_email'] as String?,
      ownerName: json['owner_name'] as String?,
      activeMembers: (json['active_members'] as num?)?.toInt() ?? 0,
      subscriptionStatus: json['subscription_status'] as String?,
    );
  }
}

class PlatformSupportNote {
  const PlatformSupportNote({
    required this.id,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.authorEmail,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String? authorId;
  final String? authorName;
  final String? authorEmail;

  factory PlatformSupportNote.fromJson(Map<String, dynamic> json) {
    return PlatformSupportNote(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      authorId: json['author_id'] as String?,
      authorName: json['author_name'] as String?,
      authorEmail: json['author_email'] as String?,
    );
  }
}

class PlatformStoreMessage {
  const PlatformStoreMessage({
    required this.id,
    required this.subject,
    required this.body,
    required this.createdAt,
    this.createdBy,
    this.isRead,
  });

  final String id;
  final String subject;
  final String body;
  final DateTime createdAt;
  final String? createdBy;
  final bool? isRead;

  factory PlatformStoreMessage.fromJson(Map<String, dynamic> json) {
    return PlatformStoreMessage(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      createdBy: json['created_by'] as String?,
      isRead: json['is_read'] as bool?,
    );
  }
}

class PlatformResetPasswordResult {
  const PlatformResetPasswordResult({
    required this.ok,
    required this.emailed,
    this.email,
    this.resetUrl,
    this.message,
    this.reason,
  });

  final bool ok;
  final bool emailed;
  final String? email;
  final String? resetUrl;
  final String? message;
  final String? reason;
}

class PlatformUsageOverview {
  const PlatformUsageOverview({
    required this.totalStores,
    required this.activeStoresToday,
    required this.activeStores7d,
    required this.paidToday,
    required this.paid7d,
    required this.gmvToday,
    required this.gmv7d,
  });

  final int totalStores;
  final int activeStoresToday;
  final int activeStores7d;
  final int paidToday;
  final int paid7d;
  final double gmvToday;
  final double gmv7d;

  factory PlatformUsageOverview.fromJson(Map<String, dynamic> json) {
    double money(Object? v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    int n(Object? v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return PlatformUsageOverview(
      totalStores: n(json['total_stores']),
      activeStoresToday: n(json['active_stores_today']),
      activeStores7d: n(json['active_stores_7d']),
      paidToday: n(json['paid_today']),
      paid7d: n(json['paid_7d']),
      gmvToday: money(json['gmv_today']),
      gmv7d: money(json['gmv_7d']),
    );
  }
}

class PlatformTxnItem {
  const PlatformTxnItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory PlatformTxnItem.fromJson(Map<String, dynamic> json) {
    double n(Object? v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return PlatformTxnItem(
      name: json['name'] as String? ?? 'Item',
      quantity: n(json['quantity']),
      unitPrice: n(json['unit_price']),
      lineTotal: n(json['line_total']),
    );
  }
}

class PlatformTransaction {
  const PlatformTransaction({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.currencyCode,
    required this.createdAt,
    this.businessType,
    this.subtotal = 0,
    this.tax = 0,
    this.refundedTotal = 0,
    this.paymentMethod,
    this.customerName,
    this.paidAt,
    this.staffName,
    this.staffEmail,
    this.itemCount = 0,
    this.items = const [],
  });

  final String id;
  final String storeId;
  final String storeName;
  final String orderNo;
  final String status;
  final String? businessType;
  final double subtotal;
  final double tax;
  final double total;
  final double refundedTotal;
  final String currencyCode;
  final String? paymentMethod;
  final String? customerName;
  final DateTime? paidAt;
  final DateTime createdAt;
  final String? staffName;
  final String? staffEmail;
  final int itemCount;
  final List<PlatformTxnItem> items;

  double get netTotal => total - refundedTotal;

  factory PlatformTransaction.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    double money(Object? v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => PlatformTxnItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <PlatformTxnItem>[];

    return PlatformTransaction(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      storeName: json['store_name'] as String? ?? 'Store',
      orderNo: json['order_no'] as String? ?? '—',
      status: json['status'] as String? ?? 'paid',
      businessType: json['business_type'] as String?,
      subtotal: money(json['subtotal']),
      tax: money(json['tax']),
      total: money(json['total']),
      refundedTotal: money(json['refunded_total']),
      currencyCode: json['currency_code'] as String? ?? 'PHP',
      paymentMethod: json['payment_method'] as String?,
      customerName: json['customer_name'] as String?,
      paidAt: parseTs(json['paid_at']),
      createdAt: parseTs(json['created_at']) ?? DateTime.now(),
      staffName: json['staff_name'] as String?,
      staffEmail: json['staff_email'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }
}

class PlatformTransactionPage {
  const PlatformTransactionPage({
    required this.transactions,
    required this.totalCount,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<PlatformTransaction> transactions;
  final int totalCount;
  final int limit;
  final int offset;
  final bool hasMore;

  factory PlatformTransactionPage.fromJson(Map<String, dynamic> json) {
    final raw = json['transactions'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => PlatformTransaction.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <PlatformTransaction>[];
    return PlatformTransactionPage(
      transactions: list,
      totalCount: (json['total_count'] as num?)?.toInt() ?? list.length,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
    );
  }
}
