import 'enums.dart';

/// Client-side mirror of RLS. Server policies remain authoritative.
abstract final class Permissions {
  static bool canSell(StoreRole role) => true;

  static bool canManageInventory(StoreRole role) => role.canManageCatalog;

  static bool canManageTeam(StoreRole role) => role.canInviteUsers;

  static bool canManageBilling(StoreRole role) => role.canManageBilling;

  static bool canCreateBranch(StoreRole role, PlanTier plan) =>
      role.canInviteUsers && plan.allowsMultiBranch;

  /// Open a franchise (linked child store). Owner/Admin of a root store only.
  static bool canOpenFranchise(StoreRole role, {required bool storeIsFranchise}) =>
      role.canInviteUsers && !storeIsFranchise;

  /// Staff: personal sales for period. Manager+: store/branch analytics.
  static bool canViewPersonalAnalytics(StoreRole role) =>
      role.canViewPersonalAnalytics;

  static bool canViewStoreAnalytics(StoreRole role) =>
      role.canViewFullAnalytics;

  static bool canViewAggregateBranches(StoreRole role, PlanTier plan) =>
      role.canSelectBranchScope && plan.allowsMultiBranch;

  /// Void / reverse a completed sale (restock + mark voided).
  static bool canVoidSales(StoreRole role) =>
      role == StoreRole.owner || role == StoreRole.admin || role == StoreRole.manager;

  /// Open / unlock the cash register for a shift.
  static bool canOpenCashRegister(StoreRole role) =>
      role == StoreRole.owner ||
      role == StoreRole.admin ||
      role == StoreRole.manager ||
      role == StoreRole.branchManager;

  /// Reports / dashboards (owner, admin, manager, branch_manager).
  static bool canViewReports(StoreRole role) => role.canViewFullAnalytics;
}
