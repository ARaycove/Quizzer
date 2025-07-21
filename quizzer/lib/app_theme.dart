import 'package:flutter/material.dart';

/// Central theme configuration for the Quizzer app.
class AppTheme {
  /// Returns the complete app theme configuration
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF87CEEB), // Light blue from logo
      secondary: Color(0xFF98FB98), // Light green from logo
      surface: Color(0xFF0A1929), // Primary background
      onPrimary: Colors.black87,
      onSecondary: Colors.black87,
      onSurface: Colors.white,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: const Color(0xFF0A1929),
    
    // App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF87CEEB), // Light blue from logo
      foregroundColor: Colors.black87,
      titleTextStyle: TextStyle(color: Colors.black87, fontSize: 18.0, fontWeight: FontWeight.bold),
      elevation: 1.0,
      toolbarHeight: 64.0, // Increased height for more spacing
    ),
    
    // Text Theme
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16.0),
      bodyMedium: TextStyle(fontSize: 16.0),
      bodySmall: TextStyle(fontSize: 16.0),
      titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor:  Color.fromRGBO(145, 236, 247, 1.0), // Light Cyan
      labelStyle: TextStyle(color: Colors.black87, fontSize: 14.0),
      hintStyle: TextStyle(color: Colors.black54, fontSize: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Colors.grey, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Colors.grey, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Color(0xFF87CEEB), width: 2.0), // Light blue from logo
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
        borderSide: BorderSide(color: Colors.red, width: 2.0),
      ),
      contentPadding: EdgeInsets.all(12.0),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF98FB98), // Light green from logo
        foregroundColor: Colors.black87,
        textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        minimumSize: const Size(80.0, 56.0), // Increased minimum height for better touch targets
        elevation: 1.0,
      ),
    ),
    
    // Floating Action Button Theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF87CEEB), // Light blue from logo
      foregroundColor: Colors.black87,
      elevation: 1.0,
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24.0,
    ),
    
    // Text Selection Theme
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.black87,
      selectionColor: Color(0xFF87CEEB), // Light blue from logo
      selectionHandleColor: Color(0xFF87CEEB), // Light blue from logo
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: const Color(0xFF1E2A3A), // Keep dark for contrast
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 1.0,
    ),
    
    // Dialog Theme
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),

    // SnackBar Theme
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF87CEEB), // Light blue from logo
      contentTextStyle: TextStyle(color: Colors.black87),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
    ),

    // Dropdown Menu Theme
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: Colors.black87),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color.fromRGBO(145, 236, 247, 1.0)),
        side: WidgetStatePropertyAll(BorderSide(color: Colors.grey)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.fromRGBO(145, 236, 247, 1.0), // Light Cyan
        labelStyle: TextStyle(color: Colors.black87, fontSize: 14.0),
        hintStyle: TextStyle(color: Colors.black54, fontSize: 12.0),
      ),
    ),
    
    // Popup Menu Theme (for dropdown options)
    popupMenuTheme: const PopupMenuThemeData(
      color: Color.fromRGBO(145, 236, 247, 1.0), // Light Cyan background
      textStyle: TextStyle(color: Colors.black87), // Black text
    ),
    


    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: Colors.grey,
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