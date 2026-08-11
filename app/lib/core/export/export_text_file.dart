import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'export_text_file_stub.dart'
    if (dart.library.js_interop) 'export_text_file_web.dart' as platform;

/// Copies [content] to the clipboard and downloads a file on web.
Future<void> exportTextFile({
  required String content,
  required String filename,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  await Clipboard.setData(ClipboardData(text: content));
  if (kIsWeb) {
    platform.downloadTextFile(
      content: content,
      filename: filename,
      mimeType: mimeType,
    );
  }
}
