import 'dart:async';

import 'package:web/web.dart' as web;

const _storageKey = 'casinpos_customer_display_v1';

void publishRaw(String raw) {
  web.window.localStorage.setItem(_storageKey, raw);
}

String? readRaw() => web.window.localStorage.getItem(_storageKey);

Stream<void> rawChangeTicks({
  Duration pollInterval = const Duration(milliseconds: 400),
}) async* {
  while (true) {
    await Future<void>.delayed(pollInterval);
    yield null;
  }
}
