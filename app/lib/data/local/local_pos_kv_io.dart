import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _file(String key) async {
  final dir = await getApplicationDocumentsDirectory();
  final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return File(p.join(dir.path, 'casinpos_cache', '$safe.json'));
}

Future<void> write(String key, String value) async {
  final f = await _file(key);
  await f.parent.create(recursive: true);
  await f.writeAsString(value, flush: true);
}

Future<String?> read(String key) async {
  final f = await _file(key);
  if (!await f.exists()) return null;
  return f.readAsString();
}

Future<void> remove(String key) async {
  final f = await _file(key);
  if (await f.exists()) await f.delete();
}
