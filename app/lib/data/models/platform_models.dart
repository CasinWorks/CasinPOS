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
      monthlyTransactionLimit: (json['monthly_transaction_limit'] as num?)?.toInt() ?? 100,
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
