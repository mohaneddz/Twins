import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'palette.dart';
import 'radius.dart';
import 'typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? TwinsPalette.dark : TwinsPalette.light;
    final bg = palette.bg;
    final surface = palette.surface;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final border = palette.border;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: TwinsColors.mikuGreen,
      onPrimary: TwinsColors.white,
      secondary: TwinsColors.vibrantBlue,
      onSecondary: TwinsColors.white,
      error: TwinsColors.danger,
      onError: TwinsColors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: palette.surfaceMuted,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: TwinsTypography.textTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TwinsTypography.heading(textPrimary, size: 20),
        // Status bar icons have to contrast with the scaffold, not the nav bar.
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: TwinsRadius.lgRadius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TwinsRadius.lgRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TwinsRadius.lgRadius,
          borderSide: const BorderSide(color: TwinsColors.mikuGreen, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: TwinsRadius.lgRadius,
          borderSide: const BorderSide(color: TwinsColors.danger, width: 1.4),
        ),
        hintStyle: TwinsTypography.body(textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TwinsColors.mikuGreen,
          foregroundColor: TwinsColors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: TwinsRadius.pillRadius),
          textStyle: TwinsTypography.heading(TwinsColors.white, size: 17),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TwinsColors.mikuGreen,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: TwinsRadius.pillRadius),
          side: const BorderSide(color: TwinsColors.mikuGreen, width: 1.4),
          textStyle: TwinsTypography.heading(TwinsColors.mikuGreen, size: 17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TwinsColors.mikuGreen,
          textStyle: TwinsTypography.label(TwinsColors.mikuGreen, size: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: TwinsRadius.lgRadius),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(TwinsRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: TwinsRadius.lgRadius),
        titleTextStyle: TwinsTypography.heading(textPrimary, size: 19),
        contentTextStyle: TwinsTypography.body(textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: TwinsRadius.mdRadius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: TwinsTypography.body(textPrimary, size: 15),
        subtitleTextStyle: TwinsTypography.body(textSecondary, size: 13),
      ),
      iconTheme: IconThemeData(color: textSecondary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: TwinsColors.mikuGreen),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? TwinsColors.darkSurfaceMuted : TwinsColors.navy,
        contentTextStyle: TwinsTypography.body(TwinsColors.white),
        shape: RoundedRectangleBorder(borderRadius: TwinsRadius.mdRadius),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
