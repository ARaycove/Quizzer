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

import 'package:text_analysis/text_analysis.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;

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


// examine keywords fields,
// for each keyword get list of synonyms,
//    for synonym in keyword:
//    1. tokenize synonym, 
//    2. see if token is in the input
//    3. if tokenized synonym matched,
//        - replace with tokenized keyword.






Future<bool> validateShortAnswer() async{
  return false;
}

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

    List<bool> individualBlanks = []; // Track individual blank correctness

    // Iterate over each blank and validate the user's answer
    for (int i = 0; i < userAnswers.length; i++) {
      String                    userAnswer = userAnswers[i];
      Map<String, List<String>> correctAnswerGroup = correctAnswers[i];
      
      // Extract the primary answer (key) and synonyms (value)
      String                    primaryAnswer = correctAnswerGroup.keys.first;
      List<String>              synonyms = correctAnswerGroup.values.first;
      
      // In order to have fill in the blank do math validation, we need to add an additional step here.

      // Is our primaryAnswer a pure integer
      late bool blankIsCorrect;
      bool isIntegerAnswer = int.tryParse(primaryAnswer.toString()) != null;
      bool isAnswerInteger = int.tryParse(userAnswer) != null;

      // TODO Future checks:
      // Is the primary answer a math expression
      // if it is we'll add a third branch to this chain

      if (isIntegerAnswer) {
        // Break off into this branch of evaluation
        
        // if the provided answer isn't also a pure integer, then the answer is wrong
        if (!isAnswerInteger) {
          blankIsCorrect = false;
        } else if (isAnswerInteger && isIntegerAnswer) {
          blankIsCorrect = int.parse(userAnswer) == int.parse(primaryAnswer);
        }
      } else {
        // Do regular text validation:
        // Check if user answer matches the primary correct answer
        // Direct string match first
        userAnswer = userAnswer.toLowerCase();
        primaryAnswer = userAnswer.toLowerCase();
        blankIsCorrect = (userAnswer == primaryAnswer);
        if (blankIsCorrect) {continue;}
        Map<String, dynamic>      similarityResult = await isSimilarTo(userAnswer, primaryAnswer);
        blankIsCorrect = similarityResult["success"];
        // If not correct, check against synonyms
        if (!blankIsCorrect && synonyms.isNotEmpty) {
          for (String synonym in synonyms) {
            Map<String, dynamic> synonymResult = await isSimilarTo(userAnswer, synonym);
            if (synonymResult["success"]) {
              blankIsCorrect = true;
              break;
            }
          }
        }
      }

      // Track this blank's result
      individualBlanks.add(blankIsCorrect);
      // If any blank is incorrect, log the details
      if (!blankIsCorrect) {
        List<String> allExpectedAnswers = [primaryAnswer, ...synonyms];
        QuizzerLogger.logMessage('validateFillInTheBlank: Blank $i incorrect. User: "$userAnswer", Expected: ${allExpectedAnswers.join(", ")}');
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

TextAnalyzer analyzer = English.analyzer;

// Normalize the input 
Future<String> normalizeString(String input) async{
  String output = input.trim().toLowerCase().replaceAll('_', ' ');
  return output;
}

Future<List<String>> callSynonymAPI(String input) async {
  try {
    // Parse input into list of words
    List<String> words = input.trim().toLowerCase().split(' ');
    
    // Build API call - join words with + for URL encoding
    String query = words.join('+');
    String url = 'https://api.datamuse.com/words?ml=$query';
    
    QuizzerLogger.logMessage('Calling Datamuse API: $url');
    
    // Make HTTP request
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      // Parse JSON response
      List<dynamic> jsonResponse = json.decode(response.body);
      
      // Extract all words and sort by score (most to least relevant)
      List<Map<String, dynamic>> wordObjects = [];
      
      for (Map<String, dynamic> wordObj in jsonResponse) {
        String word = wordObj['word'] as String;
        double score = (wordObj['score'] as num).toDouble();
        wordObjects.add({'word': word, 'score': score});
      }
      
      // Sort by score in descending order (highest score first)
      wordObjects.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      // Extract just the words in sorted order
      List<String> synonyms = wordObjects.map((obj) => obj['word'] as String).toList();
      
      QuizzerLogger.logMessage('Found ${synonyms.length} synonyms for "$input"');
      return synonyms;
    } else {
      QuizzerLogger.logError('Datamuse API returned status code: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    QuizzerLogger.logError('Error calling Datamuse API: $e');
    return [];
  }
}


/// Compares two strings for similarity using multiple validation methods.
/// 
/// This function performs a two-stage similarity check:
/// 1. First uses string_similarity package to calculate similarity score
/// 2. If similarity score is below threshold (0.5), falls back to fuzzy string matching
/// 
/// The function normalizes the input string before comparison by:
/// - Trimming whitespace
/// - Converting to lowercase
/// 
/// Returns a Map containing:
/// - "sim_score": double - Similarity score from string_similarity (0.0 to 1.0)
/// - "leven_score": double? - Levenshtein ratio from fuzzywuzzy (0.0 to 100.0), null if similarity check passes
/// - "success": bool - Whether the strings are considered similar
/// 
/// Thresholds:
/// - Similarity threshold: 0.5 (50% similarity)
/// - Typo threshold: 80.0 (80% Levenshtein ratio)
/// 
/// Example:
/// ```dart
/// Map<String, dynamic> result = await isSimilarTo("enzyme", "enyzme");
/// // Returns: {"sim_score": 0.8, "leven_score": 85.0, "success": true}
/// ```
Future<Map<String, dynamic>> isSimilarTo(String input, String comparison) async{
  input = await normalizeString(input);
  Map<String, dynamic> result = {
    "sim_score": null,
    "leven_score": null,
    "success": false
  };
  double output = input.similarityTo(comparison);
  QuizzerLogger.logMessage("$input Sim Score: $output");
  result["sim_score"] = output;
  double threshold = 0.5;
  double typoThreshold = 80;
  
  // if the strings are similar after the first check return the result:
  if (output >= threshold) {
    result["success"] = true;
    return result;
  } else {
    QuizzerLogger.logMessage("Sim score below threshold, additional checks required");
    result["success"] = false;}
  // if the strings are not similar move to next steps:

  // Do we have a typo?
  double fuzzyScore = fuzzy.ratio(input,comparison).toDouble();
  result["leven_score"] = fuzzyScore;
  QuizzerLogger.logMessage("$input => $comparison; Levenshteing_ratio: $fuzzyScore");
  if (fuzzyScore >= typoThreshold) {
    result["success"] = true;
    return result;
  } else {result["success"] = false;}


  return result;
}

Future<List<String>> returnKeywords(String input) async{
  List<String> splitTerms = await analyzer.phraseSplitter(input);
  return splitTerms;
}

Future<List<String>> returnTerms(String input) async{
  List<String> termList = analyzer.termSplitter(input);
  return termList;
}



Future<List<Token>> _tokenizeString(String input) async{
  List<Token> output = await analyzer.tokenizer(
    input,
    nGramRange: const NGramRange(1, 1)
    );
  return output;
}
String _tokensToString(List<Token> tokens) {
  // Extract terms from tokens and join with spaces
  List<String> terms = tokens.map((token) => token.term).toList();
  return terms.join(' ');
}

Future<String> tokenizeAndReconstruct(String input) async {
  // Tokenize the input string
  List<Token> tokens = await _tokenizeString(input);
  
  // Convert tokens back to string
  return _tokensToString(tokens);
}

// Tool did not output anything
dynamic expandText(String input) async{
  var output = analyzer.termExpander!(input);

  return output;
}