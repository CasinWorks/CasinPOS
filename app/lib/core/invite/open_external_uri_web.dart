import 'package:web/web.dart' as web;

Future<bool> openExternalUri(Uri uri) async {
  web.window.open(uri.toString(), '_blank');
  return true;
}
