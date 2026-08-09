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
