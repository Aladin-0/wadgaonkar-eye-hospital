import 'package:flutter/material.dart';

/// Curated medical ophthalmology color palette for Wadgaonkar Eye Hospital
class AppColors {
  AppColors._();

  // Primary Medical Brand Colors
  static const Color primary = Color(0xFF0A6847); // Rich Deep Medical Emerald
  static const Color primaryLight = Color(0xFF139669); // Bright Medical Green
  static const Color primaryDark = Color(0xFF06442E); // Deep Forest Hospital Teal
  static const Color primaryAccent = Color(0xFF0E8388); // Cyan Ophthalmology Teal

  // Secondary & Supporting Accents
  static const Color secondary = Color(0xFF0F2C59); // Trust Navy Blue
  static const Color secondaryLight = Color(0xFF1E4D8C); // Gentle Blue
  static const Color accentMint = Color(0xFFE8F5E9); // Light Mint Surface
  static const Color accentCyan = Color(0xFFE0F2F1); // Light Cyan Surface
  static const Color accentAmber = Color(0xFFFFB300); // Warm Gold for ratings/achievements

  // Background & Surface
  static const Color background = Color(0xFFF7FAFA); // Ultra-light hospital clean grey
  static const Color surface = Color(0xFFFFFFFF); // Pure white card surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF0F4F4);

  // Text Colors
  static const Color textPrimary = Color(0xFF111827); // High contrast slate/black
  static const Color textSecondary = Color(0xFF4B5563); // Muted slate grey
  static const Color textMuted = Color(0xFF9CA3AF); // Placeholder grey
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White text on buttons

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF0A6847);
  static const Color divider = Color(0xFFF3F4F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0A6847), Color(0xFF0E8388)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF06442E), Color(0xFF0A6847), Color(0xFF0E8388)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient trustNavyGradient = LinearGradient(
    colors: [Color(0xFF0F2C59), Color(0xFF1E4D8C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softMintGradient = LinearGradient(
    colors: [Color(0xFFE8F5E9), Color(0xFFE0F2F1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
