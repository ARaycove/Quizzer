import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_validation_functionality.dart';
import 'package:flutter_test/flutter_test.dart';

// Assume that the following functions and classes are already imported and available:
// Future<bool> validateMathExpressionAnswer(String userAnswer, String correctAnswer);
// class TeXParser;
// class QuizzerLogger;

/// The main body of the test suite.
void main() async {
  await QuizzerLogger.setupLogging();
  // Define a list of test cases as a List<List<String>>.
  // Each inner list contains [user_expression, correct_expression].
  final List<List<String>> exps = [
    ["x + x", "2*x"],                       // [0] true
    ["2*y + 3", "3 + 2*y"],                 // [1] true
    ["(x + x) / 2", "x"],                   // [2] true
    ["x + 1", "x + 2"],                     // [3] false not equal
    ["tan(()", "tan(x)"],                   // [4] false bad syntax
    ["(x+1) * 2", "2*x + 2"],               // [5] true
    ["sin(x) / cos(x)", "tan(x)"],          // [6] true -> identity property
    ["x + y - x", "y"],                     // [7] true
    ["x+", "x + 1"],                        // [8] false syntax error
    ["sin(sqrt(x))", "sin(sqrt(x))"]        // [9] true
  ];

  group('Math Expression Equivalence Tests', () {
      test('Case_0', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[0][0], exps[0][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_1', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[1][0], exps[1][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_2', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[2][0], exps[2][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_3', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[3][0], exps[3][1]);
        expect(isEquivalent, isFalse);
      });

      test('Case_4', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[4][0], exps[4][1]);
        expect(isEquivalent, isFalse);
      });

      test('Case_5', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[5][0], exps[5][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_6', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[6][0], exps[6][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_7', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[7][0], exps[7][1]);
        expect(isEquivalent, isTrue);
      });

      test('Case_8', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[8][0], exps[8][1]);
        expect(isEquivalent, isFalse);
      });

      test('Case_9', () async {
        final bool isEquivalent = await validateMathExpressionAnswer(exps[9][0], exps[9][1]);
        expect(isEquivalent, isTrue);
      });
  });
}