import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/palette.dart';

/// Brief branded splash while the router resolves auth/space redirects.
///
/// Deliberately mirrors the *native* splash (see the `flutter_native_splash`
/// block in pubspec.yaml): same background per theme, same mark, same size.
/// Flutter's first frame replaces the native splash, so any difference here
/// would read as a flicker on every cold start.
class SplashGate extends StatelessWidget {
  const SplashGate({super.key});

  /// Matches `flutter_native_splash.color` / `.color_dark`.
  static Color background(BuildContext context) =>
      context.isDark ? TwinsColors.navy : TwinsColors.mikuGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background(context),
      body: Center(
        child: Image.asset(
          'assets/splash.png',
          width: 160,
          height: 160,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
