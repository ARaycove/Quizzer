import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

// Module Name
const String moduleName = 'is_vowel_or_consonant';

// Vowels set for easy lookup
const Set<String> vowels = {'A', 'E', 'I', 'O', 'U'};

// Helper to format elements IS NOT needed - API expects List<Map<String, dynamic>>

void main() async {
  final List<Map<String, dynamic>> allQuestions = [];

  // Iterate through A-Z
  for (int i = 65; i <= 90; i++) {
    final String letter = String.fromCharCode(i);
    final bool isVowel = vowels.contains(letter);
    // Removed unnecessary timestamp/contributor generation

    // --- Question 1: Is [letter] a vowel? ---
    final String q1Text = 'Is $letter a vowel?';
    final int q1CorrectIndex = isVowel ? 0 : 1; // 0=True, 1=False
    final String q1AnswerText = isVowel ? '$letter is a vowel.' : '$letter is not a vowel, it is a consonant.';

    allQuestions.add({
      // Fields required by addNewQuestion API for true_false
      "question_type": "true_false", // ESSENTIAL field was missing
      "module_name": moduleName,
      "question_elements": [{'type': 'text', 'content': q1Text}], // Pass as List<Map>
      "answer_elements": [{'type': 'text', 'content': q1AnswerText}], // Pass as List<Map>
      "correct_option_index": q1CorrectIndex, // Required for true_false
    });

    // --- Question 2: Is [letter] a consonant? ---
    final String q2Text = 'Is $letter a consonant?';
    final int q2CorrectIndex = !isVowel ? 0 : 1; // 0=True, 1=False
    final String q2AnswerText = !isVowel ? '$letter is a consonant.' : '$letter is not a consonant, it is a vowel.';

    allQuestions.add({
      // Fields required by addNewQuestion API for true_false
      "question_type": "true_false", // ESSENTIAL field was missing
      "module_name": moduleName,
      "question_elements": [{'type': 'text', 'content': q2Text}], // Pass as List<Map>
      "answer_elements": [{'type': 'text', 'content': q2AnswerText}], // Pass as List<Map>
      "correct_option_index": q2CorrectIndex, // Required for true_false
    });
  }

  // Define output path
  final String outputDir = p.join(Directory.current.path, 'runtime_cache');
  final String outputFile = p.join(outputDir, '${moduleName}_questions.json');

  // Ensure directory exists
  await Directory(outputDir).create(recursive: true);

  // Write JSON file with pretty print
  final jsonString = JsonEncoder.withIndent('  ').convert(allQuestions);
  await File(outputFile).writeAsString(jsonString);

  print('Successfully generated ${allQuestions.length} questions to $outputFile');
}
