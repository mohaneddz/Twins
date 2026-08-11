import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/palette.dart';
import '../theme/radius.dart';

void showTwinsToast(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError
          ? TwinsColors.danger
          : (context.isDark ? TwinsColors.darkSurfaceMuted : TwinsColors.navy),
      shape: RoundedRectangleBorder(borderRadius: TwinsRadius.mdRadius),
      margin: const EdgeInsets.all(16),
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 3),
    ),
  );
}
