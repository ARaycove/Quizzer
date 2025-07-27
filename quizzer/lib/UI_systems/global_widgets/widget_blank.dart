import 'package:flutter/material.dart';

/// A widget that renders a text input field for fill-in-the-blank questions.
/// The width is determined by the content parameter (number of characters).
class WidgetBlank extends StatelessWidget {
  final int width; // Number of characters to determine width
  final TextEditingController controller;
  final Function(String)? onChanged;
  final bool enabled; // Whether the field is editable
  final bool? isCorrect; // Whether this blank is correct (null = not submitted)
  
  const WidgetBlank({
    super.key,
    required this.width,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Check if controller has text
    final hasText = controller.text.isNotEmpty;
    
    // Determine colors based on correctness
    Color? borderColor;
    Color? backgroundColor;
    
    if (isCorrect != null) {
      // Submitted state - show feedback colors
      if (isCorrect!) {
        borderColor = Colors.green;
        backgroundColor = const Color.fromRGBO(0, 255, 0, 0.1); // Light green
      } else {
        borderColor = Colors.red;
        backgroundColor = const Color.fromRGBO(255, 0, 0, 0.1); // Light red
      }
    }
    
    // Determine text color based on state
    Color textColor;
    if (isCorrect != null) {
      // Answered state - use theme text color for better contrast with colored backgrounds
      textColor = Theme.of(context).colorScheme.onSurface;
    } else {
      // Unanswered state - use onPrimary for contrast with default cyan background
      textColor = Theme.of(context).colorScheme.onPrimary;
    }
    
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 20.0, // Minimum width
        maxWidth: double.infinity, // Allow expansion
      ),
      child: IntrinsicWidth(
        child: TextField(
          key: ValueKey('blank_${controller.text}'), // Force rebuild when text changes
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            border: const UnderlineInputBorder(),
            hintText: hasText ? null : '█', // Show placeholder if no text
            filled: backgroundColor != null,
            fillColor: backgroundColor,
            focusedBorder: borderColor != null 
                ? UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2.0))
                : null,
            enabledBorder: borderColor != null 
                ? UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.5))
                : null,
          ),
        ),
      ),
    );
  }
}
