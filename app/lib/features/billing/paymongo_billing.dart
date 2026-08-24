import 'package:supabase_flutter/supabase_flutter.dart';

import '../../bootstrap.dart';
import '../../core/config/app_url.dart';
import '../../core/errors/app_errors.dart';

class PaymongoPriceQuote {
  const PaymongoPriceQuote({
    required this.amountCentavos,
    required this.amountLabel,
    required this.usd,
    required this.fxRate,
  });

  final int amountCentavos;
  final String amountLabel;
  final double usd;
  final double fxRate;

  String get priceLine =>
      'Premium — \$${usd.toStringAsFixed(2)} for 30 days ($amountLabel today)';
}

class PaymongoCheckout extends PaymongoPriceQuote {
  const PaymongoCheckout({
    required this.checkoutId,
    required this.checkoutUrl,
    required super.amountCentavos,
    required super.amountLabel,
    required super.usd,
    required super.fxRate,
  });

  final String checkoutId;
  final String checkoutUrl;
}

PaymongoPriceQuote _quoteFromMap(Map data) {
  return PaymongoPriceQuote(
    amountCentavos: (data['amount_centavos'] as num?)?.toInt() ?? 0,
    amountLabel: data['amount_label'] as String? ?? '₱—',
    usd: (data['usd'] as num?)?.toDouble() ?? 2.99,
    fxRate: (data['fx_rate'] as num?)?.toDouble() ?? 0,
  );
}

Future<PaymongoPriceQuote> fetchPremiumPaymongoQuote({
  required String storeId,
}) async {
  final data = await _invokeCheckout({
    'store_id': storeId,
    'preview': true,
  });
  return _quoteFromMap(data);
}

Future<PaymongoCheckout> createPremiumPaymongoCheckout({
  required String storeId,
}) async {
  final data = await _invokeCheckout({
    'store_id': storeId,
    'origin': AppUrl.publicOrigin(),
  });
  final url = data['checkout_url'] as String?;
  final id = data['checkout_id'] as String?;
  if (url == null || url.isEmpty || id == null || id.isEmpty) {
    throw AppException('PayMongo did not return a checkout link.');
  }
  final quote = _quoteFromMap(data);
  return PaymongoCheckout(
    checkoutId: id,
    checkoutUrl: url,
    amountCentavos: quote.amountCentavos,
    amountLabel: quote.amountLabel,
    usd: quote.usd,
    fxRate: quote.fxRate,
  );
}

Future<Map<dynamic, dynamic>> _invokeCheckout(Map<String, dynamic> body) async {
  final client = supabaseOrNull;
  if (client == null) {
    throw AppException('Not connected to the server.');
  }

  try {
    final res = await client.functions.invoke(
      'create-premium-checkout',
      body: body,
    );
    final data = res.data;
    if (data is Map && data['ok'] == true) return data;
    final message = data is Map
        ? (data['message'] as String? ??
            data['error'] as String? ??
            'Checkout failed')
        : 'Checkout failed';
    throw AppException(mapKnownBackendError(message) ?? message);
  } on AppException {
    rethrow;
  } on FunctionException catch (e) {
    final details = e.details;
    final message = details is Map
        ? (details['message'] as String? ??
            details['error'] as String? ??
            e.reasonPhrase)
        : (e.reasonPhrase ?? 'Checkout failed');
    throw AppException(
      mapKnownBackendError(message ?? '') ??
          message ??
          'Couldn’t start PayMongo checkout.',
    );
  }
}
