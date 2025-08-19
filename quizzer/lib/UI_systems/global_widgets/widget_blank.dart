import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// A widget that renders a text or math input field for fill-in-the-blank questions.
/// The width is determined by the content parameter (number of characters).
/// This widget is now stateful to correctly manage its controllers as requested.
class WidgetBlank extends StatefulWidget {
  final int width; // Number of characters to determine width
  final TextEditingController controller;
  // Make the mathfieldController nullable as per your design.
  final MathFieldEditingController? mathfieldController;
  final Function(String)? onChanged;
  final bool enabled; // Whether the field is editable
  final bool? isCorrect; // Whether this blank is correct (null = not submitted)
  final bool isMathExpression; // New property to decide which field to render

  const WidgetBlank({
    super.key,
    required this.width,
    required this.controller,
    this.mathfieldController,
    this.onChanged,
    this.enabled = true,
    this.isCorrect,
    this.isMathExpression = false,
  });

  @override
  WidgetBlankState createState() => WidgetBlankState();
}

/// The state class for WidgetBlank.
class WidgetBlankState extends State<WidgetBlank> {
  // We use this internal controller to manage the MathField if none is provided.
  // We make it late as we will initialize it in initState.
  late MathFieldEditingController _internalMathController;
  
  @override
  void initState() {
    super.initState();
    // CRITICAL: Check if a controller was passed. If not, create our own.
    // This is the core of the fix and aligns with your request for an
    // internally defined controller.
    _internalMathController = widget.mathfieldController ?? MathFieldEditingController();

    // We add a listener to the main controller to sync the math field.
    widget.controller.addListener(_syncWithMainController);
  }

  /// This listener keeps the math field in sync with the main controller's text.
  void _syncWithMainController() {
    // Only update if the text is different to prevent an infinite loop.
    if (_internalMathController.currentEditingValue() != widget.controller.text) {
      try {
        _internalMathController.updateValue(TeXParser(widget.controller.text).parse());
      } catch (e) {
        // Clear the math field if the text cannot be parsed as TeX.
        _internalMathController.clear();
      }
    }
  }

  @override
  void didUpdateWidget(covariant WidgetBlank oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the main controller instance changes, we must update our listener.
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_syncWithMainController);
      widget.controller.addListener(_syncWithMainController);
    }

    // If a new math controller is passed, update our internal reference.
    if (widget.mathfieldController != oldWidget.mathfieldController) {
      // If we were using an internally created controller, we must dispose it.
      if (oldWidget.mathfieldController == null) {
        oldWidget.mathfieldController?.dispose();
      }
      _internalMathController = widget.mathfieldController ?? MathFieldEditingController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncWithMainController);
    // Only dispose of our internal controller if we created it ourselves.
    if (widget.mathfieldController == null) {
      _internalMathController.dispose();
    }
    super.dispose();
  }

  // This function is now part of the state class.
  void _handleMathFieldChange(String mathfieldControlValue) {
    QuizzerLogger.logMessage("math field sent: $mathfieldControlValue");
    widget.controller.text = mathfieldControlValue;
    if (widget.onChanged != null) {
      widget.onChanged!(mathfieldControlValue);
    }

    QuizzerLogger.logMessage("The controller reports a text value of ${widget.controller.text}");
  }

  @override
  Widget build(BuildContext context) {
    Color? borderColor;
    Color? backgroundColor;

    if (widget.isCorrect != null) {
      if (widget.isCorrect!) {
        borderColor = Colors.green;
        backgroundColor = const Color.fromRGBO(0, 255, 0, 0.1);
      } else {
        borderColor = Colors.red;
        backgroundColor = const Color.fromRGBO(255, 0, 0, 0.1);
      }
    }

    Color textColor;
    if (widget.isCorrect != null) {
      textColor = Theme.of(context).colorScheme.onSurface;
    } else {
      textColor = Theme.of(context).colorScheme.onSurface;
    }
    
    Widget inputField;
    if (widget.isMathExpression) {
      inputField = SizedBox(
        height: 48.0, // Fixed height to match TextField.
        child: MathField(
          variables: const ["x", "y", "θ"],
          controller: _internalMathController,
          onChanged: _handleMathFieldChange,
          decoration: InputDecoration(
            isDense: false, // Set to false to allow for more vertical space
            border: const OutlineInputBorder(), // Use OutlineInputBorder
            hintText: 'Click/Tap to enter',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            filled: backgroundColor != null,
            fillColor: backgroundColor,
            focusedBorder: borderColor != null
                ? OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2.0))
                : null,
            enabledBorder: borderColor != null
                ? OutlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.5))
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          ),
        ),
      );
    } else {
      inputField = TextField(
        key: ValueKey('blank_${widget.controller.text}'),
        controller: widget.controller,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
        style: TextStyle(color: textColor),
        cursorColor: Theme.of(context).colorScheme.onSurface,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          hintText: widget.controller.text.isNotEmpty ? null : '█',
          filled: backgroundColor != null,
          fillColor: backgroundColor,
          focusedBorder: borderColor != null
              ? UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 2.0))
              : null,
          enabledBorder: borderColor != null
              ? UnderlineInputBorder(borderSide: BorderSide(color: borderColor, width: 1.5))
              : null,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 20.0,
        maxWidth: double.infinity,
      ),
      child: IntrinsicWidth(
        child: inputField,
      ),
    );
  }
}
