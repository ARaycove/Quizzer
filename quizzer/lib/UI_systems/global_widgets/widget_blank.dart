import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// A widget that renders a text or math input field for fill-in-the-blank questions.
/// The width is determined by the content parameter (number of characters).
class WidgetBlank extends StatefulWidget {
  final int width; // Number of characters to determine width
  // The controller is now a generic `dynamic` type to accommodate both
  // TextEditingController and MathFieldEditingController.
  final dynamic controller;
  final Function(String)? onChanged;
  final bool enabled; // Whether the field is editable
  final bool? isCorrect; // Whether this blank is correct (null = not submitted)
  final bool isMathExpression; // New property to decide which field to render
  
  // A crucial new parameter to receive the single, unified focus node from the parent.
  final FocusNode? focusNode;

  const WidgetBlank({
    super.key,
    required this.width,
    required this.controller,
    this.onChanged,
    this.enabled = true,
    this.isCorrect,
    this.isMathExpression = false,
    // The focus node is now required for proper parent-child focus management.
    this.focusNode,
  });

  @override
  WidgetBlankState createState() => WidgetBlankState();
}

/// The state class for WidgetBlank.
class WidgetBlankState extends State<WidgetBlank> {
  // We need to have a local focus node as well to manage the listeners.
  late FocusNode _localFocusNode;
  late Widget inputField;

  @override
  void initState() {
    super.initState();
    _localFocusNode = widget.focusNode ?? FocusNode();

    // The listener on the focus node is now a named function for proper lifecycle management.
    _localFocusNode.addListener(_focusListener);
  }

  /// The listener function for the focus node.
  void _focusListener() {
    if (!_localFocusNode.hasFocus) {
      QuizzerLogger.logMessage("Focus lost. Controller text is now: ${_getControllerValue()}");
    }
  }

  @override
  void didUpdateWidget(covariant WidgetBlank oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the focus node instance changes, update our listener.
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_focusListener);
      _localFocusNode = widget.focusNode ?? FocusNode();
      _localFocusNode.addListener(_focusListener);
    }
  }
  
  String _getControllerValue() {
    if (widget.isMathExpression) {
      return widget.controller.currentEditingValue();
    } else {
      return widget.controller.text;
    }
  }

  @override
  void dispose() {
    _localFocusNode.removeListener(_focusListener);
    if (widget.focusNode == null) {
      _localFocusNode.dispose();
    }
    super.dispose();
  }

  /// This private method unifies how we handle value changes for both fields.
  void _updateControllerValue(String value) {
    // Now we simply call the parent's onChanged callback.
    // The TextField's controller is updated automatically.
    if (widget.onChanged != null) {
      widget.onChanged!(value);
    }
    inputField ;
    QuizzerLogger.logMessage("The controller reports a text value of $value");
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
    
    if (widget.isMathExpression) {
      inputField = MathField(
        variables: const ["x", "y", "z", "a", "b", "c", "n", "k", "r", "p"],
        controller: widget.controller,
        // The onChanged callback still updates the controller on every keystroke
        onChanged: _updateControllerValue,
        // The onSubmitted callback also updates the controller on submission
        // or focus loss, providing a more robust solution.
        onSubmitted: _updateControllerValue,
        // Use our local focus node which has the listener.
        focusNode: _localFocusNode,
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
      );
    } else {
      inputField = TextField(
        controller: widget.controller,
        onChanged: _updateControllerValue,
        onSubmitted: _updateControllerValue,
        enabled: widget.enabled,
        style: TextStyle(color: textColor),
        cursorColor: Theme.of(context).colorScheme.onSurface,
        focusNode: _localFocusNode,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          hintText: '█', 
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

    // return ConstrainedBox(
    //   constraints: const BoxConstraints(
    //     minWidth: 20.0,
    //     maxWidth: double.infinity,
    //   ),
    //   child: IntrinsicWidth(
    //     child: inputField,
    //   ),
    // );

    if (!widget.isMathExpression) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 20.0,
          maxWidth: double.infinity,
        ),
        child: IntrinsicWidth(
          child: inputField,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: IntrinsicWidth(child: inputField),
      );
    }
  }
}
