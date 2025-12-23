import 'package:flutter/material.dart';

/// Central theme configuration for the Quizzer app.
class AppTheme {
  // New Color Palette
  static const Color bingBlue = Color(0xFF4d87f2); // Primary brand color
  static const Color powOrange = Color(0xFFfc9000); // Secondary accent
  static const Color powOrangeDark = Color(0xFFb85a02); // Dark variant
  static const Color radScarlet = Color(0xFFb25d7a); // Tertiary accent

  static const Color dingBrightGrey =
      Color(0xFFd1d1d1); // Input backgrounds, light elements
  static const Color dingLightGrey =
      Color(0xFFa3a8ae); // Secondary text, borders
  static const Color dingLineGrey =
      Color(0xFF292929); // Dividers, subtle borders
  static const Color dingMidGrey =
      Color(0xFF212121); // Primary text on light backgrounds
  static const Color dingDarkGrey = Color(0xFF121212); // Deep background

  static const Color duffLightBlue =
      Color(0xFFbce0fb); // Info states, highlights
  static const Color duffLightGreen = Color(0xFFc9efb7); // Success states

  /// Returns the complete app theme configuration
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: bingBlue, // Primary brand color
          secondary: powOrange, // Secondary accent
          tertiary: radScarlet, // Tertiary accent
          surface: dingDarkGrey, // Primary background
          surfaceContainerHighest: dingMidGrey, // Elevated surfaces
          outline: dingLineGrey, // Borders/dividers
          onPrimary: dingMidGrey, // Text on primary
          onSecondary: dingMidGrey, // Text on secondary
          onSurface: dingBrightGrey, // Text on surface
          error: radScarlet, // Error states
        ),

        // Scaffold
        scaffoldBackgroundColor: dingDarkGrey,

        // App Bar
        appBarTheme: const AppBarTheme(
          backgroundColor: bingBlue,
          foregroundColor: dingMidGrey,
          titleTextStyle: TextStyle(
              color: dingMidGrey, fontSize: 18.0, fontWeight: FontWeight.bold),
          elevation: 1.0,
          toolbarHeight: 64.0,
        ),

        // Text Theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16.0, color: dingBrightGrey),
          bodyMedium: TextStyle(fontSize: 16.0, color: dingBrightGrey),
          bodySmall: TextStyle(fontSize: 16.0, color: dingLightGrey),
          titleLarge: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: dingBrightGrey),
          titleMedium: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: dingBrightGrey),
          titleSmall: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: dingLightGrey),
        ),

        // Input Decoration Theme
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: dingBrightGrey,
          labelStyle: TextStyle(color: dingMidGrey, fontSize: 14.0),
          hintStyle: TextStyle(color: dingLightGrey, fontSize: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            borderSide: BorderSide(color: dingLineGrey, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            borderSide: BorderSide(color: dingLineGrey, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            borderSide: BorderSide(color: bingBlue, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            borderSide: BorderSide(color: radScarlet, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10.0)),
            borderSide: BorderSide(color: radScarlet, width: 2.0),
          ),
          contentPadding: EdgeInsets.all(12.0),
        ),

        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: bingBlue,
            foregroundColor: dingMidGrey,
            textStyle:
                const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            minimumSize: const Size(80.0, 56.0),
            elevation: 1.0,
          ),
        ),

        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: powOrange,
          foregroundColor: dingMidGrey,
          elevation: 1.0,
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: dingBrightGrey,
          size: 24.0,
        ),

        // Text Selection Theme
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: dingMidGrey,
          selectionColor: bingBlue,
          selectionHandleColor: bingBlue,
        ),

        // Card Theme
        cardTheme: CardThemeData(
          color: dingMidGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 1.0,
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          backgroundColor: dingMidGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),

        // SnackBar Theme
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: bingBlue,
          contentTextStyle: TextStyle(color: dingMidGrey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),

        // Dropdown Menu Theme
        dropdownMenuTheme: const DropdownMenuThemeData(
          textStyle: TextStyle(color: dingMidGrey),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(dingBrightGrey),
            side: WidgetStatePropertyAll(BorderSide(color: dingLineGrey)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: dingBrightGrey,
            labelStyle: TextStyle(color: dingMidGrey, fontSize: 14.0),
            hintStyle: TextStyle(color: dingLightGrey, fontSize: 12.0),
          ),
        ),

        // Popup Menu Theme (for dropdown options)
        popupMenuTheme: const PopupMenuThemeData(
          color: dingBrightGrey,
          textStyle: TextStyle(color: dingMidGrey),
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(
          color: dingLineGrey,
          thickness: 1.0,
          space: 1.0,
        ),

        // Page Transitions Theme
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  // SizedBox widgets for consistent spacing
  static const SizedBox sizedBoxSml = SizedBox(height: 8.0, width: 8.0);
  static const SizedBox sizedBoxMed = SizedBox(height: 12.0, width: 12.0);
  static const SizedBox sizedBoxLrg = SizedBox(height: 16.0, width: 16.0);

  // Private constructor to prevent instantiation
  AppTheme._();
}
