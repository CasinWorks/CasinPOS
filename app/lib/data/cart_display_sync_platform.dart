import 'dart:async';

String? _raw;

void publishRaw(String raw) {
  _raw = raw;
}

String? readRaw() => _raw;

Stream<void> rawChangeTicks({
  Duration pollInterval = const Duration(milliseconds: 400),
}) async* {
  while (true) {
    await Future<void>.delayed(pollInterval);
    yield null;
  }
}
