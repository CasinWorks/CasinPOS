import 'package:web/web.dart' as web;

Future<void> write(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}

Future<String?> read(String key) async {
  return web.window.localStorage.getItem(key);
}

Future<void> remove(String key) async {
  web.window.localStorage.removeItem(key);
}
