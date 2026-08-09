import 'open_external_uri_stub.dart'
    if (dart.library.html) 'open_external_uri_web.dart' as impl;

Future<bool> openExternalUri(Uri uri) => impl.openExternalUri(uri);
