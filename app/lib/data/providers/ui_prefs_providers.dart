import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppTextScale = 'casinpos.app_text_scale';

/// Optional UI text size multiplier for this device (1.0 = default).
/// Applies app-wide via [MediaQuery.textScaler]; does not change store data.
class AppTextScaleNotifier extends StateNotifier<double> {
  AppTextScaleNotifier() : super(1.0) {
    _load();
  }

  static const double min = 0.9;
  static const double max = 1.4;
  static const List<double> presets = [1.0, 1.15, 1.3];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_kAppTextScale);
    if (stored == null) return;
    state = stored.clamp(min, max);
  }

  Future<void> setScale(double value) async {
    final next = (value * 100).round() / 100;
    state = next.clamp(min, max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAppTextScale, state);
  }

  Future<void> reset() => setScale(1.0);
}

final appTextScaleProvider =
    StateNotifierProvider<AppTextScaleNotifier, double>(
  (ref) => AppTextScaleNotifier(),
);

String appTextScaleLabel(double scale) {
  if (scale <= 1.02) return 'Default';
  if (scale <= 1.2) return 'Large';
  return 'Extra large';
}
