/// Business vertical — locked at store create; drives nav & catalog kind.
enum BusinessType {
  restaurant('restaurant'),
  retail('retail'),
  service('service');

  const BusinessType(this.value);
  final String value;

  static BusinessType fromValue(String value) =>
      BusinessType.values.firstWhere((e) => e.value == value);

  String get label => switch (this) {
        BusinessType.restaurant => 'Restaurant',
        BusinessType.retail => 'Retail',
        BusinessType.service => 'Service',
      };
}

/// Store-level toggle for Service stores. Null on retail/restaurant.
enum ServicePricingMode {
  fixed('fixed'),
  quote('quote');

  const ServicePricingMode(this.value);
  final String value;

  static ServicePricingMode fromValue(String value) =>
      ServicePricingMode.values.firstWhere((e) => e.value == value);

  String get label => switch (this) {
        ServicePricingMode.fixed => 'Fixed price',
        ServicePricingMode.quote => 'Quotation-based',
      };
}

enum QuoteStatus {
  draft('draft'),
  sent('sent'),
  accepted('accepted'),
  rejected('rejected');

  const QuoteStatus(this.value);
  final String value;

  static QuoteStatus fromValue(String value) =>
      QuoteStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => QuoteStatus.draft,
      );

  String get label => switch (this) {
        QuoteStatus.draft => 'Draft',
        QuoteStatus.sent => 'Sent',
        QuoteStatus.accepted => 'Accepted',
        QuoteStatus.rejected => 'Rejected',
      };
}

enum ServiceBookingStatus {
  upcoming('upcoming'),
  completed('completed'),
  cancelled('cancelled');

  const ServiceBookingStatus(this.value);
  final String value;

  static ServiceBookingStatus fromValue(String value) =>
      ServiceBookingStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => ServiceBookingStatus.upcoming,
      );

  String get label => switch (this) {
        ServiceBookingStatus.upcoming => 'Upcoming',
        ServiceBookingStatus.completed => 'Completed',
        ServiceBookingStatus.cancelled => 'Cancelled',
      };
}

enum PaymentState {
  unpaid('unpaid'),
  depositPaid('deposit_paid'),
  paid('paid');

  const PaymentState(this.value);
  final String value;

  static PaymentState fromValue(String value) =>
      PaymentState.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PaymentState.unpaid,
      );

  String get label => switch (this) {
        PaymentState.unpaid => 'Unpaid',
        PaymentState.depositPaid => 'Deposit paid',
        PaymentState.paid => 'Paid',
      };
}

/// Separate Owner and Admin (confirmed).
enum StoreRole {
  owner('owner'),
  admin('admin'),
  manager('manager'),
  branchManager('branch_manager'),
  staff('staff');

  const StoreRole(this.value);
  final String value;

  static StoreRole fromValue(String value) =>
      StoreRole.values.firstWhere(
        (e) => e.value == value,
        orElse: () => StoreRole.staff,
      );

  /// Spec "root_owner" — store-wide Owner.
  bool get isRootOwner => this == owner;

  bool get canManageBilling => this == owner;
  bool get canInviteUsers => this == owner || this == admin;
  bool get canManageCatalog =>
      this == owner ||
      this == admin ||
      this == manager ||
      this == branchManager ||
      this == staff;
  bool get canViewFullAnalytics =>
      this == owner || this == admin || this == manager || this == branchManager;
  bool get canViewPersonalAnalytics => true;

  /// Can pick "All Branches" vs a single branch in reports.
  bool get canSelectBranchScope =>
      this == owner || this == admin || this == manager;

  /// Locked to assigned branch_ids (no merged "All" selector).
  bool get isBranchScoped => this == branchManager;

  String get label => switch (this) {
        StoreRole.owner => 'Owner',
        StoreRole.admin => 'Admin',
        StoreRole.manager => 'Manager',
        StoreRole.branchManager => 'Branch Manager',
        StoreRole.staff => 'Staff',
      };
}

enum PlanTier {
  free('free'),
  premium('premium');

  const PlanTier(this.value);
  final String value;

  static PlanTier fromValue(String value) =>
      PlanTier.values.firstWhere((e) => e.value == value);

  bool get allowsMultiBranch => this == premium;
  bool get allowsFranchise => this == premium;
}

enum AnalyticsPeriod {
  today('today'),
  week('week'),
  month('month'),
  quarter('quarter'),
  year('year');

  const AnalyticsPeriod(this.value);
  final String value;
}
