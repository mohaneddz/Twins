import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// The "¡Twins!" wordmark: teal "¡", navy/white "Twins", teal "!".
class TwinsLogo extends StatelessWidget {
  final double size;

  /// Defaults to the theme's primary text colour, so the wordmark stays
  /// legible on both the light and dark ground.
  final Color? textColor;

  const TwinsLogo({super.key, this.size = 40, this.textColor});

  @override
  Widget build(BuildContext context) {
    final style = TwinsTypography.display(
      textColor ?? context.twins.textPrimary,
      size: size,
      weight: FontWeight.w800,
    );
    final accent = style.copyWith(color: TwinsColors.mikuGreen);
    return RichText(
      text: TextSpan(children: [
        TextSpan(text: '¡', style: accent),
        TextSpan(text: 'Twins', style: style),
        TextSpan(text: '!', style: accent),
      ]),
    );
  }
}
