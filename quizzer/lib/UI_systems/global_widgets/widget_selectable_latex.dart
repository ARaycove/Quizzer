import 'package:flutter/material.dart';

// TODO: This widget is broken and needs to be fixed
class SelectableLaTexT extends StatefulWidget {
  /// The text to display with LaTeX support
  final String data;
  
  /// The delimiter to be used for inline LaTeX
  final String delimiter;
  
  /// The delimiter to be used for Display (centered, "important") LaTeX
  final String displayDelimiter;
  
  /// The delimiter to be used for line breaks outside of $delimiters$
  /// Default is '\n'
  final String breakDelimiter;
  
  /// A TextStyle used to apply styles exclusively to the mathematical equations
  final TextStyle? equationStyle;
  
  /// A callback function to be called when an error occurs while rendering the LaTeX code
  final Function(String text)? onErrorFallback;
  
  /// Callback for selection changes
  final Function(TextSelection, SelectionChangedCause?)? onSelectionChanged;
  
  /// Text style for the widget
  final TextStyle? style;
  
  /// Text alignment
  final TextAlign? textAlign;
  
  /// Text direction
  final TextDirection? textDirection;
  
  /// Locale
  final Locale? locale;
  
  /// Soft wrap
  final bool? softWrap;
  
  /// Overflow
  final TextOverflow? overflow;
  
  /// Max lines
  final int? maxLines;
  
  /// Semantics label
  final String? semanticsLabel;

  const SelectableLaTexT({
    super.key,
    required this.data,
    this.equationStyle,
    this.onErrorFallback,
    this.onSelectionChanged,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.delimiter = r'$',
    this.displayDelimiter = r'$$',
    this.breakDelimiter = r'\n',
  });

  @override
  State<SelectableLaTexT> createState() => _SelectableLaTexTState();
}

class _SelectableLaTexTState extends State<SelectableLaTexT> {
  @override
  Widget build(BuildContext context) {
    // Building [RegExp] to find any Math part of the LaTeX code by looking for the specified delimiters
    final String delimiter = widget.delimiter.replaceAll(r'$', r'\$');
    final String displayDelimiter = widget.displayDelimiter.replaceAll(r'$', r'\$');

    final String rawRegExp =
        '(($delimiter)([^$delimiter]*[^\\\\\\$delimiter])($delimiter)|($displayDelimiter)([^$displayDelimiter]*[^\\\\\\$displayDelimiter])($displayDelimiter))';
    List<RegExpMatch> matches =
        RegExp(rawRegExp, dotAll: true).allMatches(widget.data).toList();

    // If no LaTeX detected, use regular SelectableText for full selection support
    if (matches.isEmpty) {
      return SelectableText(
        widget.data,
        style: widget.style,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        onSelectionChanged: widget.onSelectionChanged,
      );
    }
    
    // If LaTeX is detected, fall back to regular SelectableText to preserve selection functionality
    return SelectableText(
      widget.data,
      style: widget.style,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      semanticsLabel: widget.semanticsLabel,
      onSelectionChanged: widget.onSelectionChanged,
    );
  }
}
