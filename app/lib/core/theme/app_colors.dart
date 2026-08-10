import 'package:flutter/material.dart';

/// Design tokens for the CasinPOS UI.
///
/// Base: dark navy / ink black. Primary accent: energetic gold used consistently
/// for CTAs, highlights, and price tags (replacing the older pink + gold split).
abstract final class AppColors {
  static const scaffold = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F172A);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);

  /// Confident primary accent (gold) — CTAs, selected states, emphasis.
  static const accent = Color(0xFFEAB308);
  static const accentSoft = Color(0xFFFEF9C3);
  static const accentDeep = Color(0xFFCA8A04);

  /// Legacy aliases — same gold family for existing call sites.
  static const restaurant = accent;
  static const restaurantSoft = accentSoft;

  /// Price tags and on-dark highlights (slightly brighter gold).
  static const retail = Color(0xFFFBBF24);
  static const retailDark = Color(0xFF0F172A);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const tableAvailable = Color(0xFF10B981);
  static const tableOccupied = Color(0xFFCA8A04);
  static const tableReserved = Color(0xFFF59E0B);

  /// Soft category pill backgrounds from the prototype.
  static const catBreakfast = Color(0xFFFDEED9);
  static const catLunch = Color(0xFFF0F0F0);
  static const catPastry = Color(0xFFFEF9C3);
  static const catSoups = Color(0xFFE8F5E9);
  static const catBowls = Color(0xFFE8EAF6);
  static const catBurgers = Color(0xFFFFE0B2);
  static const catDesserts = Color(0xFFF3E5F5);

  static const inkIntroBg = Color(0xFFF8F9FA);
  static const inkDeep = Color(0xFF0F172A);
  static const inkIndigo = Color(0xFF1E1B4B);
  static const inkRoyal = Color(0xFF312E81);
  static const inkViolet = Color(0xFF4C1D95);
  static const goldShimmer = accent;
}
