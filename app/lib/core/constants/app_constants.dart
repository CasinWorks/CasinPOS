/// Product / freemium constants locked in Phase 1 planning.
abstract final class AppConstants {
  static const freeMonthlyTransactionLimit = 50;
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
