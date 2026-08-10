import 'package:flutter/material.dart';

/// Design tokens for CasinPOS — matched to the duck + grocery-bag logo.
///
/// Dominant logo gold ≈ `#FDC401`, duck yellow ≈ `#F8E505`, ink outline black.
abstract final class AppColors {
  /// Warm cream scaffold so gold accents read as brand, not stuck-on.
  static const scaffold = Color(0xFFFFFBF0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const slate900 = Color(0xFF151515);
  static const slate800 = Color(0xFF1F1F1F);
  static const slate700 = Color(0xFF333333);
  static const slate600 = Color(0xFF4B5563);
  static const slate500 = Color(0xFF6B7280);
  static const slate400 = Color(0xFF9CA3AF);
  static const slate300 = Color(0xFFD1D5DB);
  static const slate200 = Color(0xFFE8E0C8);
  static const slate100 = Color(0xFFFFF6D6);

  /// Logo background / primary brand gold.
  static const accent = Color(0xFFFDC401);
  static const accentSoft = Color(0xFFFFF3C4);
  static const accentDeep = Color(0xFFE0A800);

  /// Duck fill yellow — price tags & bright highlights.
  static const retail = Color(0xFFF8E505);
  static const retailDark = Color(0xFF111111);

  /// Beak / energy accent for secondary emphasis.
  static const brandOrange = Color(0xFFF57C00);

  /// Legacy aliases.
  static const restaurant = accent;
  static const restaurantSoft = accentSoft;

  static const success = Color(0xFF43A047);
  static const warning = Color(0xFFF57C00);
  static const danger = Color(0xFFE53935);

  static const tableAvailable = Color(0xFF43A047);
  static const tableOccupied = Color(0xFFE0A800);
  static const tableReserved = Color(0xFFF57C00);

  static const catBreakfast = Color(0xFFFFE8B8);
  static const catLunch = Color(0xFFF5F0E6);
  static const catPastry = Color(0xFFFFF3C4);
  static const catSoups = Color(0xFFE8F5E9);
  static const catBowls = Color(0xFFFFF8E1);
  static const catBurgers = Color(0xFFFFE0B2);
  static const catDesserts = Color(0xFFFFECB3);

  static const inkIntroBg = Color(0xFFFFF8E1);
  static const inkDeep = Color(0xFF111111);
  static const inkIndigo = Color(0xFF5C4800);
  static const inkRoyal = Color(0xFFE0A800);
  static const inkViolet = Color(0xFFF57C00);
  static const goldShimmer = Color(0xFFFFF59D);
  static const brandGold = accent;
  static const brandYellow = retail;
}
