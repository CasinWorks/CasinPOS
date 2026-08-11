/// Product / freemium constants.
abstract final class AppConstants {
  static const freeMonthlyTransactionLimit = 100;
  /// Free = owner + 1 teammate.
  static const freeTeamSeatLimit = 2;
  static const defaultCurrencyCode = 'PHP';
  static const defaultCurrencySymbol = '₱';

  /// Analytics periods available to staff (personal) and managers (store).
  static const analyticsPeriods = [
    'today',
    'week',
    'month',
    'quarter',
    'year',
  ];
}
