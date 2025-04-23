import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
        color: ColorWheel.secondaryBackground,
        borderRadius: ColorWheel.cardBorderRadius,
        border: Border.all(color: ColorWheel.accent.withAlpha(128)),
      ),
      child: Column(
        children: [
          Padding(
            padding: ColorWheel.standardPadding,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _optionsController,
                    focusNode: _optionsFocusNode,
                    style: ColorWheel.defaultText,
                    decoration: InputDecoration(
                      hintText: 'Enter an option',
                      hintStyle: ColorWheel.secondaryTextStyle,
                      filled: true,
                      fillColor: ColorWheel.primaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.accent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.accent), 
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.accent, width: 2.0), 
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ColorWheel.standardPaddingValue,
                        vertical: ColorWheel.standardPaddingValue,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addOption();
                      }
                    },
                  ),
                ),
                const SizedBox(width: ColorWheel.standardPaddingValue / 2),
                IconButton(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, color: ColorWheel.accent),
                ),
              ],
            ),
          ),
          ...widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ColorWheel.standardPaddingValue,
                vertical: ColorWheel.standardPaddingValue / 2,
              ),
              title: Text(
                option,
                style: ColorWheel.defaultText,
              ),
              leading: IconButton(
                icon: Icon(
                  widget.correctOptionIndex == index
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                  color: widget.correctOptionIndex == index
                      ? ColorWheel.buttonSuccess
                      : ColorWheel.buttonError,
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
                icon: const Icon(Icons.delete, color: ColorWheel.buttonError),
                onPressed: () => _removeOption(index),
              ),
            );
          }),
        ],
      ),
    );
  }
} 