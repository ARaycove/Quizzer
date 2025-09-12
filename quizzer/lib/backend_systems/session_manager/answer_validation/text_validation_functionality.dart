// Package Reference Table (for text validation and NLP)
//
// | Package           | Purpose                              | pub.dev Link                                      |
// |-------------------|--------------------------------------|---------------------------------------------------|
// | string_similarity | String similarity scoring            | https://pub.dev/packages/string_similarity         |
// | fuzzywuzzy        | Fuzzy string matching                | https://pub.dev/packages/fuzzywuzzy               |
// | levenshtein       | Levenshtein distance                 | https://pub.dev/packages/levenshtein              |
// | nlp               | Basic NLP (tokenize, stem, etc.)     | https://pub.dev/packages/nlp                      |
// | text_analysis     | Keyword extraction, sentiment, etc.  | https://pub.dev/packages/text_analysis            |
// | string_scanner    | String parsing/tokenization           | https://pub.dev/packages/string_scanner           |

// Based on docks from string_similarity healed and sealed are higher sim than france and FrancE
// We could maybe use this by normalizing, but It doesn't appear to be what we're looking for. . .
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/math_validation.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:math_keyboard/math_keyboard.dart';


// For validation of short_answer and fill_in_the_blank questions
// additional fields for validation
// ----------------------------------------
// custom fields for short_answer questions
// answer_sentence TEXT (The string that holds the short answer, should be limited to a single sentence)
// keywords TEXT (json string, {keyword: [synonym_1, synonym_2], keyword: [], keyword: []})
// Validation:
// take in user input (A String)
// normalize the input
// normalize values and use text_similarity isSimilarTo for initial comparison (if meets greater than threshold, then correct)


// custom fields for fill_in_the_blank questions:
// options TEXT (existing field, each option is a blank and should be restricted to one word)
// blank_answers TEXT (List<String> index aligns with options list ->
//  - [keyword, keyword, keyword]
//  - [keyword, keyword])
// Validation:
// For each option use isSimilarTo and compare, if fail check option against the keyword synonyms instead.
// -----------------------------------------



final Set<String> exactEvalCases = {
"==", "!=", "isdigit()", "++",'System.out.println("Hello, World");', "a'b", "sudo dpkg -i filename.deb",
"java example one two three", "boolean myValue = true;", "int[][] twoD_arr = new int[10][20];"
};
final Set<String> typoCheckOnlyCases = {
"endosymbiosis", "stromatolites", "generalized linear model", "adenosine triphosphate",
"cumulative distribution function", "probability density", "prior probability", "charged", "uncharged",
"positively", "negatively"
};
/// Determines the validation type based on the content of the answer.
String getValidationType(String answer) {
  // 2. Typo check only

  String selectedType;
  // 1. Try to parse the answer as a number first. (we're using try because it throws an error if the statement isn't parsable, so try then catch the error if we get it)
  try {
    TeXParser(answer).parse();
    // If the parse is successful, it's a valid math expression.
    selectedType = 'math_expression';
  } catch (e) {
    // if TexParser fails to parse we'll evaluate whether to do exact string match or similiarity string match
    if (exactEvalCases.contains(answer)) {
      selectedType = "exact_string_match";
    } 
    else if (typoCheckOnlyCases.contains(answer)) {
      selectedType = "typo_check_only";
    }
    
    else {selectedType = 'string';}
  }
  QuizzerLogger.logMessage("Evaluation type for this option is: $selectedType");
  return selectedType;
}

// typedef to ensure our validator functions have the correct signature.
typedef BlankValidator = Future<bool> Function(String userAnswer, String correctAnswer);

/// Validates a single number-based answer.
/// If the correctAnswer is an integer we will evaluate correctness strictly, provided must be an exact match
Future<bool> validateMathExpressionAnswer(String userAnswer, String correctAnswer) async {
  bool returnValue = await evaluateMathExpressionsEquivalent(userExpression: userAnswer, correctExpression: correctAnswer);
  return returnValue;
}

Future<bool> validateStringWithTypoCheck(String userAnswer, String correctAnswer) async{
  double fuzzyScore = await getFuzzyScoreForTypo(userAnswer, correctAnswer);
  // Identity (These cases the algorithm is not properly detecting)

  if (correctAnswer == "positively" && userAnswer == "negatively") {return false;}
  else if (correctAnswer == "negativley" && userAnswer == "positively") {return false;}
  else if (correctAnswer.contains("sexual") && userAnswer.contains("asexual")) {return false;} // A typo check sees an added "A" as a typo, instead of a negation modifier to the word
  else if (correctAnswer.contains("asexual") && !userAnswer.contains("asexual")) {return false;} // if the correct answer is asexual the user answer must contain asexual, if the (a) is not included it is wrong

  return fuzzyScore >= 0.90;
}


Future<bool> validateExactMatch(String userAnswer, String correctAnswer) async{
  return (userAnswer == correctAnswer);
}
// --- The main validation function with your completed logic ---
/// Return Data:
/// {isCorrect: bool, ind_blanks: [bool, bool, bool]}
Future<Map<String, dynamic>> validateFillInTheBlank(Map<String, dynamic> questionData, List<String> userAnswers) async{
  Map<String, dynamic> returnData = {};
  try {
    // Validate the type being checked is a fill_in_the_blank:
    String questionType = questionData["question_type"];
    if (questionType != "fill_in_the_blank") {
      QuizzerLogger.logError('validateFillInTheBlank called with wrong question type: $questionType');
      returnData["isCorrect"] = false;
      returnData["ind_blanks"] = [];
      return returnData;
    }
    
    // Extract validation field for this type
    List<Map<String, List<String>>> correctAnswers = questionData["answers_to_blanks"];
    
    // Validate that we have the same number of user answers as expected blanks
    if (userAnswers.length != correctAnswers.length) {
      QuizzerLogger.logError('validateFillInTheBlank: Number of user answers (${userAnswers.length}) does not match number of expected blanks (${correctAnswers.length})');
      returnData["isCorrect"] = false;
      returnData["ind_blanks"] = List<bool>.filled(correctAnswers.length, false);
      return returnData;
    }
    
    final Map<String, BlankValidator> validators = {
      'math_expression': validateMathExpressionAnswer,
      'string': validateStringAnswer,
      'exact_string_match': validateExactMatch,
      'typo_check_only': validateStringWithTypoCheck,
      // 'code': validateCodeAnswer,
    };
    
    List<bool> individualBlanks = [];

    for (int i = 0; i < userAnswers.length; i++) {
      String userAnswer = userAnswers[i];
      Map<String, List<String>> correctAnswerGroup = correctAnswers[i];
      
      List<String> possibleAnswers = [correctAnswerGroup.keys.first] + correctAnswerGroup.values.first;
      
      bool blankIsCorrect = false;
      
      // Validation Loop
      for (String validOption in possibleAnswers) {
        // How should we validate this option
        String validationType = getValidationType(validOption);
        // Feed the type into our map to get the validation function we will use
        BlankValidator? validator = validators[validationType];

        // If it returns null, something seriously wrong went down, crash Quizzer immediately
        if (validator == null) {
          QuizzerLogger.logError("No Validation Function found for type: $validationType");
          throw Exception("No Validation Function found for type: $validationType");
        }
        
        // Now run the validation, if true set blankIsCorrect to true and break out of this nested for loop to proceed to the nest blank
        if (await validator(userAnswer, validOption)) {
          blankIsCorrect = true;
          break; // Stop checking other possible answers once one is a match.
        }
      }
      
      // Track this blank's result
      individualBlanks.add(blankIsCorrect);

      // Log incorrect blanks
      if (!blankIsCorrect) {
        QuizzerLogger.logMessage('validateFillInTheBlank: Blank $i incorrect. User: "$userAnswer", Expected: ${possibleAnswers.join(", ")}');
      }
    }
    
    // Determine overall correctness
    bool overallCorrect = individualBlanks.every((blank) => blank);
    if (overallCorrect) {
      QuizzerLogger.logSuccess('validateFillInTheBlank: All blanks correct');
    }
    
    returnData["isCorrect"] = overallCorrect;
    returnData["ind_blanks"] = individualBlanks;
    return returnData;
    
  } catch (e) {
    QuizzerLogger.logError('Error in validateFillInTheBlank: $e');
    returnData["isCorrect"] = false;
    returnData["ind_blanks"] = [];
    return returnData;
  }
}

// ======================================================================



