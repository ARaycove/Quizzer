import 'package:flutter/material.dart';
import 'package:quizzer/backend/quizzer_logging.dart';

// Colors
const Color _backgroundColor = Color(0xFF0A1929); // Primary Background
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _primaryColor = Color(0xFF4CAF50); // Accent Color
const Color _errorColor = Color(0xFFD64747); // Error red
const Color _textColor = Colors.white; // Primary Text
const Color _hintColor = Colors.grey; // Secondary Text
const double _borderRadius = 12.0;
const double _spacing = 16.0;

class QuestionEntryOptionsDialog extends StatefulWidget {
  final List<String> options;
  final Function(List<String>) onOptionsChanged;
  final int correctOptionIndex;
  final Function(int) onCorrectOptionChanged;

  const QuestionEntryOptionsDialog({
    super.key,
    required this.options,
    required this.onOptionsChanged,
    required this.correctOptionIndex,
    required this.onCorrectOptionChanged,
  });

  @override
  State<QuestionEntryOptionsDialog> createState() => _QuestionEntryOptionsDialogState();
}

class _QuestionEntryOptionsDialogState extends State<QuestionEntryOptionsDialog> {
  final TextEditingController _optionsController = TextEditingController();
  final FocusNode _optionsFocusNode = FocusNode();

  void _addOption() {
    if (widget.options.length < 6 && _optionsController.text.isNotEmpty) {
      final newOption = _optionsController.text;
      setState(() {
        widget.options.add(newOption);
        _optionsController.clear();
        if (_optionsFocusNode.hasFocus) {
          _optionsFocusNode.requestFocus();
        }
      });
      widget.onOptionsChanged(List<String>.from(widget.options));
      QuizzerLogger.logMessage('''
RAW STATE - Add Option:
widget.options: ${widget.options}
widget.options.runtimeType: ${widget.options.runtimeType}
widget.options.length: ${widget.options.length}
widget.correctOptionIndex: ${widget.correctOptionIndex}
widget.correctOptionIndex.runtimeType: ${widget.correctOptionIndex.runtimeType}
newOption: $newOption
newOption.runtimeType: ${newOption.runtimeType}
''');
    }
  }

  void _removeOption(int index) {
    final optionToRemove = widget.options[index];
    setState(() {
      widget.options.removeAt(index);
      if (widget.correctOptionIndex == index) {
        widget.onCorrectOptionChanged(-1);
      } else if (widget.correctOptionIndex > index) {
        widget.onCorrectOptionChanged(widget.correctOptionIndex - 1);
      }
    });
    widget.onOptionsChanged(List<String>.from(widget.options));
    QuizzerLogger.logMessage('''
RAW STATE - Remove Option:
widget.options: ${widget.options}
widget.options.runtimeType: ${widget.options.runtimeType}
widget.options.length: ${widget.options.length}
widget.correctOptionIndex: ${widget.correctOptionIndex}
widget.correctOptionIndex.runtimeType: ${widget.correctOptionIndex.runtimeType}
index: $index
index.runtimeType: ${index.runtimeType}
optionToRemove: $optionToRemove
optionToRemove.runtimeType: ${optionToRemove.runtimeType}
''');
  }

  @override
  void dispose() {
    _optionsController.dispose();
    _optionsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: _primaryColor.withAlpha(128)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(_spacing),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _optionsController,
                    focusNode: _optionsFocusNode,
                    style: const TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Enter an option',
                      hintStyle: const TextStyle(color: _hintColor),
                      filled: true,
                      fillColor: _backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_borderRadius),
                        borderSide: const BorderSide(color: _primaryColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: _spacing,
                        vertical: _spacing,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addOption();
                      }
                    },
                  ),
                ),
                const SizedBox(width: _spacing / 2),
                IconButton(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, color: _primaryColor),
                ),
              ],
            ),
          ),
          ...widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _spacing,
                vertical: _spacing / 2,
              ),
              title: Text(
                option,
                style: const TextStyle(color: _textColor),
              ),
              leading: IconButton(
                icon: Icon(
                  widget.correctOptionIndex == index
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: widget.correctOptionIndex == index
                      ? _primaryColor
                      : _errorColor,
                  size: 28,
                ),
                onPressed: () {
                  widget.onCorrectOptionChanged(
                    widget.correctOptionIndex == index ? -1 : index,
                  );
                  QuizzerLogger.logMessage(
                    'Correct option changed to: ${widget.correctOptionIndex == index ? -1 : index}',
                  );
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: _errorColor),
                onPressed: () => _removeOption(index),
              ),
            );
          }),
        ],
      ),
    );
  }
} 