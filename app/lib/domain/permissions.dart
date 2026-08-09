import 'enums.dart';

/// Client-side mirror of RLS. Server policies remain authoritative.
abstract final class Permissions {
  static bool canSell(StoreRole role) => true;

  static bool canManageInventory(StoreRole role) => role.canManageCatalog;

  static bool canManageTeam(StoreRole role) => role.canInviteUsers;

  static bool canManageBilling(StoreRole role) => role.canManageBilling;

  static bool canCreateBranch(StoreRole role, PlanTier plan) =>
      role.canInviteUsers && plan.allowsMultiBranch;

  /// Staff: personal sales for period. Manager+: store/branch analytics.
  static bool canViewPersonalAnalytics(StoreRole role) =>
      role.canViewPersonalAnalytics;

  static bool canViewStoreAnalytics(StoreRole role) =>
      role.canViewFullAnalytics;

  static bool canViewAggregateBranches(StoreRole role, PlanTier plan) =>
      role.canViewFullAnalytics && plan.allowsMultiBranch;

  /// Void / reverse a completed sale (restock + mark voided).
  static bool canVoidSales(StoreRole role) =>
      role == StoreRole.owner || role == StoreRole.admin || role == StoreRole.manager;
}
