import '../config/app_url.dart';
import '../invite/open_external_uri.dart';

/// Opens the customer-facing display in a new browser tab / window.
Future<bool> openCustomerDisplayWindow() {
  final uri = Uri.parse('${AppUrl.publicOrigin()}/display');
  return openExternalUri(uri);
}
