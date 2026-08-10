import '../../domain/enums.dart';
import 'pos_models.dart';

class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.name,
    required this.businessType,
    required this.planTier,
    required this.currencyCode,
    required this.currencySymbol,
    required this.transactionsThisPeriod,
    required this.monthlyTransactionLimit,
    this.acceptGcash = true,
    this.acceptMaya = true,
    this.acceptCard = true,
    this.franchisorStoreId,
    this.franchiseNotes,
    this.businessTin,
    this.businessAddress,
  });

  final String id;
  final String name;
  final BusinessType businessType;
  final PlanTier planTier;
  final String currencyCode;
  final String currencySymbol;
  final int transactionsThisPeriod;
  final int monthlyTransactionLimit;
  final bool acceptGcash;
  final bool acceptMaya;
  final bool acceptCard;
  /// When set, this store is a franchise of the franchisor store.
  final String? franchisorStoreId;
  final String? franchiseNotes;
  final String? businessTin;
  final String? businessAddress;

  bool get isFranchise => franchisorStoreId != null;

  /// Cash is always available. Optional methods follow store settings.
  List<PaymentMethod> get enabledPaymentMethods => [
        PaymentMethod.cash,
        if (acceptGcash) PaymentMethod.gcash,
        if (acceptMaya) PaymentMethod.maya,
        if (acceptCard) PaymentMethod.card,
      ];

  bool accepts(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => true,
        PaymentMethod.gcash => acceptGcash,
        PaymentMethod.maya => acceptMaya,
        PaymentMethod.card => acceptCard,
      };

  StoreSummary copyWith({
    String? name,
    bool? acceptGcash,
    bool? acceptMaya,
    bool? acceptCard,
    String? franchisorStoreId,
    String? franchiseNotes,
    String? businessTin,
    String? businessAddress,
  }) {
    return StoreSummary(
      id: id,
      name: name ?? this.name,
      businessType: businessType,
      planTier: planTier,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      transactionsThisPeriod: transactionsThisPeriod,
      monthlyTransactionLimit: monthlyTransactionLimit,
      acceptGcash: acceptGcash ?? this.acceptGcash,
      acceptMaya: acceptMaya ?? this.acceptMaya,
      acceptCard: acceptCard ?? this.acceptCard,
      franchisorStoreId: franchisorStoreId ?? this.franchisorStoreId,
      franchiseNotes: franchiseNotes ?? this.franchiseNotes,
      businessTin: businessTin ?? this.businessTin,
      businessAddress: businessAddress ?? this.businessAddress,
    );
  }

  factory StoreSummary.fromJson(Map<String, dynamic> json) {
    return StoreSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: BusinessType.fromValue(json['business_type'] as String),
      planTier: PlanTier.fromValue(json['plan_tier'] as String),
      currencyCode: json['currency_code'] as String? ?? 'PHP',
      currencySymbol: json['currency_symbol'] as String? ?? '₱',
      transactionsThisPeriod: json['transactions_this_period'] as int? ?? 0,
      monthlyTransactionLimit: json['monthly_transaction_limit'] as int? ?? 50,
      acceptGcash: json['accept_gcash'] as bool? ?? true,
      acceptMaya: json['accept_maya'] as bool? ?? true,
      acceptCard: json['accept_card'] as bool? ?? true,
      franchisorStoreId: json['franchisor_store_id'] as String?,
      franchiseNotes: json['franchise_notes'] as String?,
      businessTin: json['business_tin'] as String?,
      businessAddress: json['business_address'] as String?,
    );
  }
}

/// Result of [StoreRepository.createFranchiseStore].
class FranchiseCreateResult {
  const FranchiseCreateResult({
    required this.storeId,
    required this.branchId,
    required this.storeName,
    required this.ownerEmail,
    required this.ownerLinked,
    required this.categoriesCloned,
    required this.productsCloned,
    required this.copyStock,
    this.inviteToken,
  });

  final String storeId;
  final String branchId;
  final String storeName;
  final String ownerEmail;
  final bool ownerLinked;
  final int categoriesCloned;
  final int productsCloned;
  final bool copyStock;
  final String? inviteToken;

  factory FranchiseCreateResult.fromJson(Map<String, dynamic> json) {
    return FranchiseCreateResult(
      storeId: json['store_id'] as String,
      branchId: json['branch_id'] as String,
      storeName: json['store_name'] as String? ?? '',
      ownerEmail: json['owner_email'] as String? ?? '',
      ownerLinked: json['owner_linked'] as bool? ?? false,
      categoriesCloned: (json['categories_cloned'] as num?)?.toInt() ?? 0,
      productsCloned: (json['products_cloned'] as num?)?.toInt() ?? 0,
      copyStock: json['copy_stock'] as bool? ?? true,
      inviteToken: json['invite_token'] as String?,
    );
  }
}

class FranchiseStoreSummary {
  const FranchiseStoreSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.ownerLinked,
    required this.productsCount,
    this.franchiseNotes,
    this.ownerEmail,
    this.inviteStatus,
    this.inviteToken,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool ownerLinked;
  final int productsCount;
  final String? franchiseNotes;
  final String? ownerEmail;
  final String? inviteStatus;
  final String? inviteToken;

  factory FranchiseStoreSummary.fromJson(Map<String, dynamic> json) {
    return FranchiseStoreSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      franchiseNotes: json['franchise_notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ownerEmail: json['owner_email'] as String?,
      ownerLinked: json['owner_linked'] as bool? ?? false,
      inviteStatus: json['invite_status'] as String?,
      inviteToken: json['invite_token'] as String?,
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StoreMembership {
  const StoreMembership({
    required this.id,
    required this.storeId,
    required this.role,
    required this.store,
  });

  final String id;
  final String storeId;
  final StoreRole role;
  final StoreSummary store;

  factory StoreMembership.fromJson(Map<String, dynamic> json) {
    final storeJson = json['stores'] as Map<String, dynamic>;
    return StoreMembership(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      role: StoreRole.fromValue(json['role'] as String),
      store: StoreSummary.fromJson(storeJson),
    );
  }
}
