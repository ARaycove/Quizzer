import 'package:flutter/material.dart';

/// A central repository for UI theme constants like colors, text styles, 
/// padding, spacing, and border radii, based on the project's design system.
class ColorWheel {
  // --- Colors ---
  static const Color primaryBackground = Color(0xFF0A1929);  // Dark Blue
  static const Color secondaryBackground = Color(0xFF1E2A3A);
  static const Color accent = Color(0xFF4CAF50);            // Green
  static const Color textInputBackground = Color.fromRGBO(145, 236, 247, 1.0); // Light Cyan
  
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Colors.grey;          // Grey for secondary info
  static const Color inputText = Colors.black87;           // For text typed into fields
  static const Color hintText = Colors.black54;            // For hint text in fields
  
  static const Color buttonSuccess = Color.fromRGBO(71, 214, 93, 1.0); // Green
  static const Color buttonSecondary = Colors.grey;
  static const Color buttonError = Color.fromRGBO(214, 71, 71, 1.0);   // Red
  static const Color warning = Color(0xFFFFCDD2); // Light Red (Using Material's red[100])

  // --- Typography ---
  static const TextStyle defaultText = TextStyle(
    color: primaryText,
    fontSize: 16.0,
  );
  static const TextStyle titleText = TextStyle(
    color: primaryText,
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle inputLabelText = TextStyle(
    color: inputText, // Black87 as per guidelines
    fontSize: 14.0,
  );
  static const TextStyle buttonText = TextStyle(
    color: primaryText,
    fontSize: 16.0, // Defaulting to larger end of 14-16px range
  );
  static const TextStyle buttonTextBold = TextStyle(
    color: primaryText,
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle secondaryTextStyle = TextStyle(
    color: secondaryText, // Grey
    fontSize: 16.0, // Assuming default size for secondary text
  );
   static const TextStyle hintTextStyle = TextStyle(
    color: hintText, // Black54 as per guidelines
    fontSize: 12.0,
  );

  // --- Layout & Spacing (Doubles) ---
  static const double standardPaddingValue = 16.0;
  static const double inputFieldPaddingValue = 12.0;
  static const double majorSectionSpacing = 20.0;
  static const double relatedElementSpacing = 10.0;
  static const double formFieldSpacing = 8.0;
  static const double buttonHorizontalSpacing = 16.0;
  static const double iconHorizontalSpacing = 8.0;
  static const double standardIconSize = 24.0;

  // --- Padding (EdgeInsets) ---
  static const EdgeInsets standardPadding = EdgeInsets.all(standardPaddingValue);
  static const EdgeInsets inputFieldPadding = EdgeInsets.all(inputFieldPaddingValue);
  // Example for symmetric button padding from guidelines (adjust if needed)
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: 32.0, 
      vertical: standardPaddingValue, // Reuse standard padding value for vertical
  );

  // --- Borders & Radii ---
  static const double buttonRadiusValue = 10.0; // Max of 8-10px range
  static const double textFieldRadiusValue = 10.0; // Max of 8-10px range
  static const double cardRadiusValue = 12.0;

  static final BorderRadius buttonBorderRadius = BorderRadius.circular(buttonRadiusValue);
  static final BorderRadius textFieldBorderRadius = BorderRadius.circular(textFieldRadiusValue);
  static final BorderRadius cardBorderRadius = BorderRadius.circular(cardRadiusValue);

  // --- Animations ---
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);
  static const Curve standardAnimationCurve = Curves.easeInOut;

  // Private constructor to prevent instantiation
  ColorWheel._(); 
}
