/// Business vertical — locked at store create; drives nav & catalog kind.
enum BusinessType {
  restaurant('restaurant'),
  retail('retail');

  const BusinessType(this.value);
  final String value;

  static BusinessType fromValue(String value) =>
      BusinessType.values.firstWhere((e) => e.value == value);
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
