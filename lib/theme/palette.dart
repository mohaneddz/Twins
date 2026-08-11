import 'package:flutter/material.dart';
import 'colors.dart';

/// Semantic surface tokens for the current theme.
///
/// Widgets should ask for a *role* (`context.twins.bg`, `.textSecondary`)
/// rather than picking a literal out of [TwinsColors]. That is what makes the
/// light/dark switch actually work: every screen reads the same token and the
/// token changes with the theme.
@immutable
class TwinsPalette extends ThemeExtension<TwinsPalette> {
  /// Scaffold background.
  final Color bg;

  /// Raised content: cards, sheets, dialogs.
  final Color surface;

  /// Recessed content: inputs, inactive chips, settings groups.
  final Color surfaceMuted;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Text/icons drawn on top of the brand green.
  final Color onBrand;

  /// The bottom nav bar. Stays deep navy in *both* themes - the brand sheet
  /// shows the same navy bar under a light search screen and a dark
  /// dashboard, so it reads as a fixed brand element rather than a surface.
  final Color navBar;
  final Color navInactive;

  /// Inactive filter-chip fill + label (mint pill in the brand sheet).
  final Color chipBg;
  final Color chipText;

  /// Base colour for card drop shadows, already alpha-adjusted per theme.
  final Color shadow;

  const TwinsPalette({
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.onBrand,
    required this.navBar,
    required this.navInactive,
    required this.chipBg,
    required this.chipText,
    required this.shadow,
  });

  static const light = TwinsPalette(
    bg: TwinsColors.lightBg,
    surface: TwinsColors.lightSurface,
    surfaceMuted: TwinsColors.lightSurfaceMuted,
    border: TwinsColors.lightBorder,
    textPrimary: TwinsColors.lightTextPrimary,
    textSecondary: TwinsColors.lightTextSecondary,
    onBrand: TwinsColors.white,
    navBar: TwinsColors.navy,
    navInactive: Color(0x8CFFFFFF),
    chipBg: TwinsColors.mikuMist,
    chipText: Color(0xFF0E8F84),
    shadow: Color(0x14000000),
  );

  static const dark = TwinsPalette(
    bg: TwinsColors.darkBg,
    surface: TwinsColors.darkSurface,
    surfaceMuted: TwinsColors.darkSurfaceMuted,
    border: TwinsColors.darkBorder,
    textPrimary: TwinsColors.darkTextPrimary,
    textSecondary: TwinsColors.darkTextSecondary,
    onBrand: TwinsColors.white,
    navBar: TwinsColors.darkSurface,
    navInactive: Color(0x8CFFFFFF),
    chipBg: TwinsColors.darkSurfaceMuted,
    chipText: TwinsColors.mikuLight,
    shadow: Color(0x66000000),
  );

  @override
  TwinsPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? onBrand,
    Color? navBar,
    Color? navInactive,
    Color? chipBg,
    Color? chipText,
    Color? shadow,
  }) {
    return TwinsPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onBrand: onBrand ?? this.onBrand,
      navBar: navBar ?? this.navBar,
      navInactive: navInactive ?? this.navInactive,
      chipBg: chipBg ?? this.chipBg,
      chipText: chipText ?? this.chipText,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  TwinsPalette lerp(covariant TwinsPalette? other, double t) {
    if (other == null) return this;
    return TwinsPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipText: Color.lerp(chipText, other.chipText, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension TwinsPaletteX on BuildContext {
  /// Semantic colours for the active theme.
  TwinsPalette get twins => Theme.of(this).extension<TwinsPalette>() ?? TwinsPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Picks a readable foreground for an arbitrary background (folder colours are
/// user-chosen, so contrast has to be computed rather than assumed).
///
/// The threshold is 0.40 rather than the usual 0.50 to match the brand sheet,
/// which puts navy on every pastel — including mid-luminance pink (~0.44) —
/// and reserves white for the saturated brand colours (miku green ~0.35,
/// sakura pink ~0.36). A 0.50 cut would flip the pastels to white, which the
/// design never does.
Color onColor(Color background) =>
    background.computeLuminance() > 0.40 ? TwinsColors.navy : TwinsColors.white;
