import 'package:flutter/material.dart';

class QuestionTypeCountsWidget extends StatelessWidget {
  final Map<String, int> questionCountByType;

  const QuestionTypeCountsWidget({
    super.key,
    required this.questionCountByType,
  });

  // Define icons for each question type
  IconData _getIconForQuestionType(String questionType) {
    switch (questionType) {
      case 'multiple_choice':
        return Icons.radio_button_checked;
      case 'true_false':
        return Icons.check_circle_outline;
      case 'select_all_that_apply':
        return Icons.checklist;
      case 'fill_in_the_blank':
        return Icons.edit_note;
      case 'sort_order':
        return Icons.sort;
      default:
        return Icons.help_outline;
    }
  }

  // Get full display name for tooltip
  String _getTooltipTextForQuestionType(String questionType) {
    switch (questionType) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'true_false':
        return 'True/False';
      case 'select_all_that_apply':
        return 'Select All That Apply';
      case 'fill_in_the_blank':
        return 'Fill in the Blank';
      case 'sort_order':
        return 'Sort Order';
      default:
        return questionType;
    }
  }

  Widget _buildQuestionTypeItem(MapEntry<String, int> entry) {
    final String questionType = entry.key;
    final int count = entry.value;
    final IconData icon = _getIconForQuestionType(questionType);

    return Tooltip(
      message: '${_getTooltipTextForQuestionType(questionType)}: $count',
      child: Row(
        children: [
          Icon(icon),
          Text('$count'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out question types with 0 count
    final Map<String, int> nonZeroCounts = Map.fromEntries(
      questionCountByType.entries.where((entry) => entry.value > 0)
    );

    if (nonZeroCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final int itemCount = nonZeroCounts.length;
    final int rows = (itemCount + 1) ~/ 2; // Round up
    
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Row(
          children: List.generate(2, (colIndex) {
            final int itemIndex = colIndex * rows + rowIndex;
            if (itemIndex >= itemCount) {
              return const Expanded(child: SizedBox());
            }
            final entry = nonZeroCounts.entries.elementAt(itemIndex);
            return Expanded(child: _buildQuestionTypeItem(entry));
          }),
        );
      }),
    );
  }
}
