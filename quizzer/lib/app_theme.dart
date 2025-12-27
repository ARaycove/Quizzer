import 'package:flutter/material.dart';

/// Central theme configuration for the Quizzer app.
/// Theme: "Orbit Dark" - High-contrast dark theme for developer tools and dashboards
class AppTheme {
  // === NEUTRAL SCALE (Backgrounds & Borders) ===
  static const Color bgCanvas = Color(0xFF121212); // Deepest void - main background
  static const Color bgSurface = Color(0xFF1E1E1E); // Soft charcoal - cards, editor
  static const Color bgElevated = Color(0xFF2D2E30); // Lighter grey - dropdowns, modals
  static const Color bgInput = Color(0xFF161616); // Input black - text fields, terminal
  
  static const Color borderBase = Color(0xFF333333); // Subtle divider
  static const Color borderActive = Color(0xFF454545); // Active divider - focus rings
  
  // === TYPOGRAPHY ===
  static const Color textPrimary = Color(0xFFEDEDED); // Off-white - main text
  static const Color textMuted = Color(0xFF9E9E9E); // Neutral grey - labels, secondary
  static const Color textDisabled = Color(0xFF5F5F5F); // Dark grey - disabled states
  
  // === BRAND & ACTION (The Greens) ===
  static const Color brandPrimary = Color(0xFF3ECF8E); // Electric mint - primary actions
  static const Color brandHover = Color(0xFF34B27B); // Deep mint - hover states
  static const Color brandSurface = Color(0xFF003D26); // Dark emerald - subtle fills
  static const Color brandDark = Color(0xFF006F45); // Run button background
  static const Color brandContrast = Color(0xFF000000); // Text on mint
  
  // === DATA VISUALIZATION (The Accents) ===
  static const Color chartBlue = Color(0xFF669DF6); // Cornflower - info, links
  static const Color chartPink = Color(0xFFFF4081); // Neon rose - errors, critical
  static const Color chartOrange = Color(0xFFF59E0B); // Amber - warnings
  static const Color chartPurple = Color(0xFFB794F6); // Lavender - 4th data color
  
  // === UTILITY ===
  static const Color selection = Color(0xFF3A3D41); // Text highlight

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
          bodyLarge: TextStyle(fontSize: 16.0, color: dingMidGrey),
          bodyMedium: TextStyle(fontSize: 16.0, color: dingMidGrey),
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
          labelStyle: TextStyle(color: dingMidGrey, fontSize: 16.0),
          hintStyle: TextStyle(color: dingLightGrey, fontSize: 16.0),
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
            foregroundColor: dingDarkGrey,
            textStyle:
                const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
            minimumSize: const Size(80.0, 40.0),
            elevation: 1.0,
          ),
        ),

        // Floating Action Button Theme
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: powOrangeDim,
          foregroundColor: dingDarkGrey,
          elevation: 1.0,
          extendedTextStyle:
              const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          extendedPadding:
              const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
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

  // Font sizes for text boxes and inputs
  static const double tbLarge = 28.0;
  static const double tbMed = 24.0;

  // Private constructor to prevent instantiation
  AppTheme._();
}
