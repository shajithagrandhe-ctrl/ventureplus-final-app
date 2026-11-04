import 'package:flutter/material.dart';

abstract final class Brand {
  // Website tokens: dark glass shell, cream primary, and role accents.
  static const background = Color(0xFF141A26);
  static const backgroundDeep = Color(0xFF0B1020);
  static const sidebar = Color(0xFF101725);
  static const sidebarAccent = Color(0xFF26354F);
  static const surface = Color(0xB82D384B);
  static const surfaceSolid = Color(0xFFFFFFFF);
  static const muted = Color(0xFF253147);
  static const border = Color(0x33FFFFFF);
  static const ink = Color(0xFFF8FAFC);
  static const inkDark = Color(0xFF1E293B);
  static const secondary = Color(0xFFCBD5E1);
  static const cream = Color(0xFFF7EFD3);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF4B740);
  static const amberLight = Color(0x33F4B740);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF7DD3FC);

  // Compatibility aliases used by existing workflow widgets.
  static const sage900 = blue;
  static const sage700 = blue;
  static const sage500 = secondary;
  static const sage100 = Color(0x332563EB);
  static const walnut900 = ink;
  static const walnut700 = secondary;

  static const radius = 14.0;
  static const gutter = 20.0;
  static const gap = 16.0;
  static const compact = 8.0;
  static const section = 32.0;
  static const maxWidth = 1180.0;
  static const tablet = 760.0;
  static const press = Duration(milliseconds: 140);
  static const transition = Duration(milliseconds: 220);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
      primary: cream,
      onPrimary: backgroundDeep,
      secondary: blue,
      onSecondary: surfaceSolid,
      tertiary: amber,
      surface: surface,
      onSurface: ink,
      error: error,
      onError: backgroundDeep,
      outline: border,
      outlineVariant: border,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Manrope',
      fontFamilyFallback: const [
        'Plus Jakarta Sans',
        'Segoe UI',
        'Roboto',
        'Arial',
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MotionAwareTransitions(),
          TargetPlatform.iOS: MotionAwareTransitions(),
          TargetPlatform.macOS: MotionAwareTransitions(),
          TargetPlatform.windows: MotionAwareTransitions(),
          TargetPlatform.linux: MotionAwareTransitions(),
          TargetPlatform.fuchsia: MotionAwareTransitions(),
        },
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: ink,
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
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shadowColor: Colors.black54,
        shape: shape.copyWith(side: const BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: const TextStyle(color: secondary),
        hintStyle: const TextStyle(color: Color(0x99CBD5E1)),
        prefixIconColor: const Color(0x99CBD5E1),
        suffixIconColor: const Color(0x99CBD5E1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: cream, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        errorStyle: const TextStyle(color: error),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: cream,
          foregroundColor: backgroundDeep,
          shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          foregroundColor: ink,
          shape: shape,
          side: const BorderSide(color: border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: sidebar,
        indicatorColor: sidebarAccent,
        indicatorShape: StadiumBorder(),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: secondary)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: secondary,
          ),
        ),
        height: 76,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: secondary,
        textColor: ink,
        subtitleTextStyle: TextStyle(color: secondary, fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x1AFFFFFF),
        selectedColor: const Color(0x333B82F6),
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: cream),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sidebar,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sidebar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: sidebar,
        contentTextStyle: TextStyle(color: ink),
      ),
    );
  }
}

class MotionAwareTransitions extends PageTransitionsBuilder {
  const MotionAwareTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}
