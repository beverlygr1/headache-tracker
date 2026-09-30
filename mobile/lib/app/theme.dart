import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF6F8FD);
  static const desktopCanvas = Color(0xFFE8EBF2);
  static const card = Colors.white;
  static const ink = Color(0xFF101827);
  static const muted = Color(0xFF7E8798);
  static const line = Color(0xFFE9EDF5);
  static const blue = Color(0xFF3D8BF2);
  static const blueSoft = Color(0xFFDCEBFF);
  static const bluePale = Color(0xFFEEF5FF);
  static const mint = Color(0xFFBFF6EA);
  static const teal = Color(0xFF19B8AA);
  static const navy = Color(0xFF111A2A);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.line,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 29,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
      ),
      titleLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        color: AppColors.ink,
        fontSize: 13,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        height: 1.3,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
