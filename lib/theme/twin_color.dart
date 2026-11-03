import 'package:flutter/material.dart';

/// The colours a twin can pick for the app (Settings → Our colours). The
/// picked one replaces Miku green everywhere on their phone, including the
/// launcher icon, and the other twin sees their stuff drawn in it.
enum TwinColor {
  miku('Miku', Color(0xFF00B3A4), Color(0xFF7EE7E1), Color(0xFFE0FFFA), Color(0xFF0E8F84)),
  sakura('Sakura', Color(0xFFF06AB4), Color(0xFFFFB3DD), Color(0xFFFFE8F5), Color(0xFFB83C82)),
  lavender('Lavender', Color(0xFF8E7CF0), Color(0xFFC9BFFF), Color(0xFFF0ECFF), Color(0xFF5F4FC0)),
  sky('Sky', Color(0xFF3D9BE9), Color(0xFFA9D5FA), Color(0xFFE6F3FF), Color(0xFF1F6FB2)),
  peach('Peach', Color(0xFFF08A4B), Color(0xFFFFC9A3), Color(0xFFFFF0E5), Color(0xFFB85A1E));

  final String label;

  /// Buttons, icons, highlights.
  final Color accent;

  /// Softer accent for dark backgrounds and decorations.
  final Color light;

  /// Barely-there tint: my chat bubbles, light chips.
  final Color mist;

  /// Accent dark enough to read as text on [mist].
  final Color deep;

  const TwinColor(this.label, this.accent, this.light, this.mist, this.deep);

  static TwinColor fromKey(String? key) =>
      TwinColor.values.firstWhere((c) => c.name == key, orElse: () => TwinColor.miku);

  /// What to draw the other twin in when they picked the same colour as me,
  /// so the two of us never look alike.
  TwinColor get standIn => this == TwinColor.sakura ? TwinColor.miku : TwinColor.sakura;
}
