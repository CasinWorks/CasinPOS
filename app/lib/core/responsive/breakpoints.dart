import 'package:flutter/widgets.dart';

/// Shared breakpoints for phone / tablet / desktop (Flutter Web).
abstract final class Breakpoints {
  static const phoneMax = 600.0;
  static const tabletMax = 1024.0;

  static bool isPhone(double width) => width < phoneMax;
  static bool isTablet(double width) => width >= phoneMax && width < tabletMax;
  static bool isDesktop(double width) => width >= tabletMax;

  /// Persistent sidebar + optional cart tray.
  static bool useSidebar(double width) => width >= phoneMax;

  /// Right cart tray beside POS (tablet landscape / desktop).
  static bool useCartTray(double width) => width >= 900;
}

enum AppFormFactor { phone, tablet, desktop }

AppFormFactor formFactorFor(double width) {
  if (Breakpoints.isPhone(width)) return AppFormFactor.phone;
  if (Breakpoints.isTablet(width)) return AppFormFactor.tablet;
  return AppFormFactor.desktop;
}

extension FormFactorContext on BuildContext {
  Size get _size => MediaQuery.sizeOf(this);

  AppFormFactor get formFactor => formFactorFor(_size.width);
  bool get isPhone => Breakpoints.isPhone(_size.width);
  bool get isTablet => Breakpoints.isTablet(_size.width);
  bool get isDesktop => Breakpoints.isDesktop(_size.width);
  bool get useSidebar => Breakpoints.useSidebar(_size.width);
  bool get useCartTray => Breakpoints.useCartTray(_size.width);
}
