import 'package:flutter/material.dart';

/// ¡Twins! brand palette. Centralized so no hex codes are scattered
/// through feature widgets.
class TwinsColors {
  TwinsColors._();

  static const navy = Color(0xFF0F172A);
  static const mikuGreen = Color(0xFF00B3A4);
  static const mikuLight = Color(0xFF7EE7E1);
  static const mikuMist = Color(0xFFE0FFFA);
  static const skyBlue = Color(0xFFBDE5F6);
  static const vibrantBlue = Color(0xFF4D7CFE);
  static const sakuraPink = Color(0xFFFF6EC7);
  static const white = Color(0xFFFFFFFF);

  // Secondary folder accent colors (from the dashboard mock: mint, pink, purple, blue).
  static const folderMint = Color(0xFF8DEBD9);
  static const folderPink = Color(0xFFFF8FA3);
  static const folderPurple = Color(0xFFB9A6FF);
  static const folderBlue = Color(0xFFA8B9FF);
  static const folderPeach = Color(0xFFFFD9A0);

  static const List<Color> folderPalette = [
    folderMint,
    folderPink,
    folderPurple,
    folderBlue,
    folderPeach,
    mikuLight,
    skyBlue,
    sakuraPink,
  ];

  // Light theme surfaces
  static const lightBg = Color(0xFFF7F8FA);
  static const lightSurface = white;
  static const lightSurfaceMuted = Color(0xFFF0F2F5);
  static const lightBorder = Color(0xFFE3E7EC);
  static const lightTextPrimary = navy;
  static const lightTextSecondary = Color(0xFF5B6472);

  // Dark theme surfaces (deep navy, not pure black)
  static const darkBg = navy;
  static const darkSurface = Color(0xFF16223D);
  static const darkSurfaceMuted = Color(0xFF1C2A48);
  static const darkBorder = Color(0xFF283A5E);
  static const darkTextPrimary = white;
  static const darkTextSecondary = Color(0xFFA9B6CC);

  static const success = mikuGreen;
  static const danger = Color(0xFFFF5C6C);
  static const warning = Color(0xFFFFB86B);
}
