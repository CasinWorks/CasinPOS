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
    this.productCount = 0,
    this.activeProductCount = 0,
    this.subscriptionStatus,
    this.signupChannel,
    this.billingProvider,
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
  final int productCount;
  final int activeProductCount;
  final String? subscriptionStatus;
  final String? signupChannel;
  final String? billingProvider;

  bool get isSuspended => suspendedAt != null;

  bool get hasCatalog => productCount > 0;

  String get signupChannelLabel => switch (signupChannel) {
        'ios' => 'iOS',
        'macos' => 'Mac',
        'android' => 'Android',
        'web' => 'Web',
        _ => '—',
      };

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
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      activeProductCount: (json['active_product_count'] as num?)?.toInt() ?? 0,
      subscriptionStatus: json['subscription_status'] as String?,
      signupChannel: json['signup_channel'] as String?,
      billingProvider: json['billing_provider'] as String?,
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
    this.appFeesToday = 0,
    this.appFees7d = 0,
    this.appRevenueToday = 0,
    this.appRevenue7d = 0,
  });

  final int totalStores;
  final int activeStoresToday;
  final int activeStores7d;
  final int paidToday;
  final int paid7d;
  final double gmvToday;
  final double gmv7d;
  final int appFeesToday;
  final int appFees7d;
  final double appRevenueToday;
  final double appRevenue7d;

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
      appFeesToday: n(json['app_fees_today']),
      appFees7d: n(json['app_fees_7d']),
      appRevenueToday: money(json['app_revenue_today']),
      appRevenue7d: money(json['app_revenue_7d']),
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

class PlatformSetupProduct {
  const PlatformSetupProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    this.stock,
    this.kind,
    this.sku,
    this.categoryName,
    this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final bool isActive;
  final double? stock;
  final String? kind;
  final String? sku;
  final String? categoryName;
  final DateTime? createdAt;

  factory PlatformSetupProduct.fromJson(Map<String, dynamic> json) {
    double? n(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse('$v');
    }

    return PlatformSetupProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Item',
      price: n(json['price']) ?? 0,
      stock: n(json['stock']),
      isActive: json['is_active'] != false,
      kind: json['kind'] as String?,
      sku: json['sku'] as String?,
      categoryName: json['category_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class PlatformStoreSetup {
  const PlatformStoreSetup({
    required this.storeId,
    required this.productCount,
    required this.activeProductCount,
    required this.categoryCount,
    required this.branchCount,
    required this.hasCatalog,
    this.latestProductAt,
    this.products = const [],
    this.categories = const [],
  });

  final String storeId;
  final int productCount;
  final int activeProductCount;
  final int categoryCount;
  final int branchCount;
  final bool hasCatalog;
  final DateTime? latestProductAt;
  final List<PlatformSetupProduct> products;
  final List<String> categories;

  factory PlatformStoreSetup.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map>()
            .map((e) => PlatformSetupProduct.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <PlatformSetupProduct>[];
    final rawCats = json['categories'];
    final categories = <String>[];
    if (rawCats is List) {
      for (final c in rawCats) {
        if (c is Map && c['name'] != null) {
          categories.add(c['name'].toString());
        } else if (c is String) {
          categories.add(c);
        }
      }
    }
    return PlatformStoreSetup(
      storeId: json['store_id'] as String? ?? '',
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      activeProductCount: (json['active_product_count'] as num?)?.toInt() ?? 0,
      categoryCount: (json['category_count'] as num?)?.toInt() ?? 0,
      branchCount: (json['branch_count'] as num?)?.toInt() ?? 0,
      hasCatalog: json['has_catalog'] == true,
      latestProductAt:
          DateTime.tryParse(json['latest_product_at']?.toString() ?? '')?.toLocal(),
      products: products,
      categories: categories,
    );
  }
}

class PlatformAnalyticsDay {
  const PlatformAnalyticsDay({
    required this.day,
    required this.registered,
    required this.converted,
    required this.sales,
    required this.gmv,
    this.registeredIos = 0,
    this.registeredWeb = 0,
    this.webPaid = 0,
  });

  final DateTime day;
  final int registered;
  final int converted;
  final int sales;
  final double gmv;
  final int registeredIos;
  final int registeredWeb;
  final int webPaid;

  factory PlatformAnalyticsDay.fromJson(Map<String, dynamic> json) {
    final rawDay = json['day']?.toString() ?? '';
    return PlatformAnalyticsDay(
      day: DateTime.tryParse(rawDay)?.toLocal() ??
          DateTime.tryParse('${rawDay}T00:00:00')?.toLocal() ??
          DateTime.now(),
      registered: (json['registered'] as num?)?.toInt() ?? 0,
      converted: (json['converted'] as num?)?.toInt() ?? 0,
      sales: (json['sales'] as num?)?.toInt() ?? 0,
      gmv: (json['gmv'] as num?)?.toDouble() ?? 0,
      registeredIos: (json['registered_ios'] as num?)?.toInt() ?? 0,
      registeredWeb: (json['registered_web'] as num?)?.toInt() ?? 0,
      webPaid: (json['web_paid'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformAnalyticsSeries {
  const PlatformAnalyticsSeries({
    required this.days,
    required this.registered,
    required this.converted,
    required this.sales,
    required this.gmv,
    required this.conversionRate,
    required this.series,
    this.registeredIos = 0,
    this.registeredWeb = 0,
    this.webPaid = 0,
  });

  final int days;
  final int registered;
  final int converted;
  final int sales;
  final double gmv;
  final double conversionRate;
  final List<PlatformAnalyticsDay> series;
  final int registeredIos;
  final int registeredWeb;
  final int webPaid;

  factory PlatformAnalyticsSeries.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};
    final raw = json['series'];
    final series = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => PlatformAnalyticsDay.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <PlatformAnalyticsDay>[];
    return PlatformAnalyticsSeries(
      days: (json['days'] as num?)?.toInt() ?? series.length,
      registered: (totals['registered'] as num?)?.toInt() ?? 0,
      converted: (totals['converted'] as num?)?.toInt() ?? 0,
      sales: (totals['sales'] as num?)?.toInt() ?? 0,
      gmv: (totals['gmv'] as num?)?.toDouble() ?? 0,
      conversionRate: (totals['conversion_rate'] as num?)?.toDouble() ?? 0,
      registeredIos: (totals['registered_ios'] as num?)?.toInt() ?? 0,
      registeredWeb: (totals['registered_web'] as num?)?.toInt() ?? 0,
      webPaid: (totals['web_paid'] as num?)?.toInt() ?? 0,
      series: series,
    );
  }
}
