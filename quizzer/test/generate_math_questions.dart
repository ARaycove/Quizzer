import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ==========================================
// Test Data Generation Script
// ==========================================

void main() async {
  final List<Map<String, dynamic>> allQuestions = [];
  final Random random = Random();
  const String moduleName = 'elementary_addition';
  const String questionType = 'multiple_choice';

  print('Generating questions for module: $moduleName...');

  for (int n1 = 1; n1 <= 9; n1++) {
    for (int n2 = 1; n2 <= 9; n2++) {
      final int correctAnswer = n1 + n2;
      final String questionText = '$n1 + $n2 = ?';
      final Set<int> optionsSet = {}; // Use a Set to ensure unique options

      // 1. Add correct answer
      optionsSet.add(correctAnswer);

      // 2. Add concatenated option
      final int concatOption = int.parse('$n1$n2');
      optionsSet.add(concatOption);

      // 3. Add nearby options (+1, -1), ensuring they are positive and different
      if (correctAnswer + 1 > 0) {
        optionsSet.add(correctAnswer + 1);
      }
      if (correctAnswer - 1 > 0) {
        optionsSet.add(correctAnswer - 1);
      }

      // 4. Add random distractors until we have ~6 options total
      //    Range: 1 to 18 (max sum) + 5 = 23 for some spread
      while (optionsSet.length < 6) {
        final int randomOption = random.nextInt(23) + 1; // 1 to 23
        optionsSet.add(randomOption);
      }

      // Convert options Set to List<Map<String, dynamic>> and shuffle
      final List<Map<String, dynamic>> optionsList = optionsSet.map((option) {
        return {'type': 'text', 'content': option.toString()};
      }).toList();
      optionsList.shuffle(random);

      // Find the index of the correct answer MAP in the shuffled list
      final String correctAnswerString = correctAnswer.toString();
      final int correctIndex = optionsList.indexWhere((optionMap) {
        return optionMap['content'] == correctAnswerString;
      });
      assert(correctIndex != -1, 'Correct answer map not found in options list!');

      // Create the question map
      final Map<String, dynamic> questionMap = {
        'moduleName': moduleName,
        'questionType': questionType,
        'questionElements': [
          {'type': 'text', 'content': questionText}
        ],
        // Answer elements are simple text representation of the correct answer
        'answerElements': [
          {'type': 'text', 'content': correctAnswer.toString()}
        ],
        'options': optionsList, // Use the list of maps
        'correctOptionIndex': correctIndex,
      };

      allQuestions.add(questionMap);
    }
  }

  print('Generated ${allQuestions.length} questions.');

  // Define output path (relative to project root)
  final String outputDir = 'runtime_cache';
  final String outputFilePath = '$outputDir/elementary_addition_questions.json';

  // Ensure directory exists
  final Directory dir = Directory(outputDir);
  if (!await dir.exists()) {
    print('Creating directory: $outputDir');
    await dir.create(recursive: true);
  }

  // Encode to JSON
  final JsonEncoder encoder = JsonEncoder.withIndent('  '); // Pretty print
  final String jsonString = encoder.convert(allQuestions);

  // Write to file
  final File outputFile = File(outputFilePath);
  try {
    await outputFile.writeAsString(jsonString);
    print('Successfully wrote questions to: $outputFilePath');
  } catch (e) {
    print('Error writing questions to file: $e');
  }
}