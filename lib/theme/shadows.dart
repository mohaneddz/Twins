import 'package:flutter/material.dart';

class TwinsShadows {
  TwinsShadows._();

  static List<BoxShadow> card(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> floating(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF0F172A).withValues(alpha: 0.14),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
