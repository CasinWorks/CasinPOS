import 'package:web/web.dart' as web;

void downloadTextFile({
  required String content,
  required String filename,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final href = 'data:$mimeType,${Uri.encodeComponent(content)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = href
    ..download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
