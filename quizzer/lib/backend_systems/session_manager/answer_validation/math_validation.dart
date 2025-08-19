import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

/// Must provide two expressions on which they will be evaluated for equivalency
/// Optional values can be passed for the variables, otherwise they will be defaulted
/// Variables:
/// x = 2.0
/// y = math.pi
/// theta = 45
Future<bool> evaluateMathExpressionsEquivalent({   
    required String correctExpression, 
    required String userExpression, 
    double x = 2.0, 
    double y = math.pi, 
    double theta = 45
  })async{
  bool result = false;
  // variables are x, y, and θ
  // more to come, will update as we move on
  ExpressionParser p = GrammarParser();
  late Expression correctAnswer;
  late Expression providedAnswer;
  try {
    // Attempt to parse both the correct and user expressions.
    // This is the step that can throw a FormatException.
    correctAnswer = p.parse(correctExpression).simplify();
    providedAnswer = p.parse(userExpression).simplify();
    QuizzerLogger.logMessage("Simplified comparison does:\n$correctAnswer==$providedAnswer?");
  } on FormatException {
    // If a FormatException is caught, it means one of the expressions is malformed.
    // In this case, they cannot be equivalent, so we return false.
    QuizzerLogger.logWarning("FormatException caught: One or both expressions are malformed.");
    return false;
  }
  List<String> variables = ["x", "y", "θ"];

  var context = ContextModel()
    ..bindVariable(Variable(variables[0]), Number(2.0))
    ..bindVariable(Variable(variables[1]), Number(math.pi))
    ..bindVariable(Variable(variables[2]), Number(45));

  // Docs:
  //
  // Mathematical expressions must be evaluated under a certain [EvaluationType].
  // Currently there are three types, but not all expressions support each type. If you try to evaluate an expression with an unsupported type, it will raise an [UnimplementedError] or [UnsupportedError].
  // REAL
  // VECTOR
  // INTERVAL
  late dynamic evaluatedCorrectAnswer;
  late dynamic evaluatedUserAnswer;
  final evaluationTypes = [EvaluationType.REAL,EvaluationType.VECTOR,EvaluationType.INTERVAL];

  for (final type in evaluationTypes) {
    try {
      evaluatedCorrectAnswer = correctAnswer.evaluate(type, context);
      evaluatedUserAnswer = providedAnswer.evaluate(type, context);
      // If evaluation succeeds, break the loop
      break; 
    } on UnimplementedError {
      // Continue to the next type in the list
      continue;
    } on UnsupportedError {
      // Continue to the next type in the list
      continue;
    }
  }

  // After the loop, check if the answers were successfully evaluated.
  // If evaluatedCorrectAnswer or evaluatedUserAnswer are still uninitialized, it means all attempts failed.
  if (evaluatedCorrectAnswer == null || evaluatedUserAnswer == null) {
    // If we get here, it means all evaluation types failed.
    // "Guess you're fucked"
    result = false;
    return result;
  }

  result = (evaluatedCorrectAnswer == evaluatedUserAnswer);
  return result;
}