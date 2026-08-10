import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';

/// True when the device reports a usable network interface.
/// Not the same as [isSupabaseReady] (compile-time keys).
final connectivityOnlineProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  Future<bool> probe() async {
    final results = await connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return false;
    }
    return !results.every((r) => r == ConnectivityResult.none);
  }

  final controller = StreamController<bool>.broadcast();
  var last = true;

  Future<void> emit() async {
    final next = await probe();
    if (next != last || !controller.hasListener) {
      last = next;
      if (!controller.isClosed) controller.add(next);
    }
  }

  emit();
  final sub = connectivity.onConnectivityChanged.listen((_) => emit());
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Convenience: keys present AND network looks available.
final cloudReachableProvider = Provider<bool>((ref) {
  if (!isSupabaseReady) return false;
  return ref.watch(connectivityOnlineProvider).valueOrNull ?? true;
});
