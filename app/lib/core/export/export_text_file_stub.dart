void downloadTextFile({
  required String content,
  required String filename,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  // No-op on IO (mobile/desktop) — clipboard already set by caller.
}
