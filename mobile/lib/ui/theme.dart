import 'package:flutter/material.dart';

abstract final class Brand {
  static const sage900 = Color(0xFF263D32);
  static const sage700 = Color(0xFF426653);
  static const sage500 = Color(0xFF789681);
  static const sage100 = Color(0xFFE8EFE9);
  static const walnut900 = Color(0xFF3D2B22);
  static const walnut700 = Color(0xFF624638);
  static const amber = Color(0xFFD99A32);
  static const amberLight = Color(0xFFFFF1D4);
  static const background = Color(0xFFF8F8F4);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFFF0F1EB);
  static const ink = Color(0xFF202820);
  static const secondary = Color(0xFF626B62);
  static const border = Color(0xFFDDE2DA);
  static const success = Color(0xFF2F6B46);
  static const warning = Color(0xFF8A5A0A);
  static const error = Color(0xFFB42318);
  static const info = Color(0xFF285E8E);
  static const radius = 12.0;
  static const gutter = 20.0;
  static const gap = 16.0;
  static const compact = 8.0;
  static const section = 32.0;
  static const maxWidth = 1040.0;
  static const tablet = 720.0;
  static const press = Duration(milliseconds: 140);
  static const transition = Duration(milliseconds: 220);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage700,
      brightness: Brightness.light,
      primary: sage700,
      onPrimary: surface,
      secondary: walnut700,
      onSecondary: surface,
      tertiary: amber,
      surface: surface,
      onSurface: ink,
      error: error,
      outline: secondary,
      outlineVariant: border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: walnut900,
        ),
        headlineMedium: const TextStyle(
          fontSize: 26,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: ink),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: secondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: shape.copyWith(side: const BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: secondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: sage700, width: 2),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: shape,
          side: const BorderSide(color: secondary),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: sage100,
        height: 76,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: sage900,
      ),
    );
  }
}
