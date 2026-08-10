import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped whenever the outbox changes so pending-count UI refreshes.
final outboxTickProvider = StateProvider<int>((ref) => 0);

void bumpOutboxTick(Ref ref) {
  ref.read(outboxTickProvider.notifier).state++;
}
