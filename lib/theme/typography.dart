import 'package:flutter/material.dart';

/// Rounded, playful display font for headings/logo (matches the bubbly
/// "¡Twins!" wordmark), paired with a clean readable font for body text.
///
/// Both families are bundled variable fonts (see `assets/fonts`) rather than
/// fetched at runtime, so the brand type renders on first launch and offline
/// instead of falling back to Roboto while a download is in flight.
class TwinsTypography {
  TwinsTypography._();

  /// Brand display family — the brand sheet's "Kooma Bold" stand-in.
  static const displayFamily = 'Baloo2';

  /// Body family — the brand sheet's "Inter Rounded" stand-in.
  static const bodyFamily = 'Nunito';

  /// Variable fonts need the weight axis set explicitly; [fontWeight] alone
  /// only picks a named instance, which these files do not carry.
  static List<FontVariation> _wght(FontWeight weight) => [FontVariation('wght', weight.value.toDouble())];

  static TextStyle _style({
    required String family,
    required Color color,
    required double size,
    required FontWeight weight,
    required double height,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        fontVariations: _wght(weight),
        color: color,
        height: height,
      );

  static TextStyle display(Color color, {double size = 32, FontWeight weight = FontWeight.w800}) =>
      _style(family: displayFamily, color: color, size: size, weight: weight, height: 1.15);

  static TextStyle heading(Color color, {double size = 20, FontWeight weight = FontWeight.w700}) =>
      _style(family: displayFamily, color: color, size: size, weight: weight, height: 1.2);

  static TextStyle body(Color color, {double size = 15, FontWeight weight = FontWeight.w400}) =>
      _style(family: bodyFamily, color: color, size: size, weight: weight, height: 1.4);

  static TextStyle label(Color color, {double size = 13, FontWeight weight = FontWeight.w600}) =>
      _style(family: bodyFamily, color: color, size: size, weight: weight, height: 1.3);

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: display(primary, size: 36),
        headlineMedium: heading(primary, size: 24),
        headlineSmall: heading(primary, size: 20),
        titleMedium: heading(primary, size: 17),
        bodyLarge: body(primary, size: 16),
        bodyMedium: body(primary, size: 15),
        bodySmall: body(secondary, size: 13),
        labelLarge: label(primary, size: 15),
        labelMedium: label(secondary, size: 13),
        labelSmall: label(secondary, size: 11),
      );
}
