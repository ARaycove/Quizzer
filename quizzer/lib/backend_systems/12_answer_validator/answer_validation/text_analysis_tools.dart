import 'package:text_analysis/text_analysis.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;
import 'package:string_similarity/string_similarity.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


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
Future<Map<String, dynamic>> isSimilarTo(String input, String comparison) async {
  input = await normalizeString(input);
  comparison = await normalizeString(comparison);
  
  Map<String, dynamic> result = {
    "sim_score": null,
    "leven_score": null,
    "success": false
  };
  
  double simScore = input.similarityTo(comparison);
  result["sim_score"] = simScore;
  
  double fuzzyScore = fuzzy.ratio(input, comparison) / 100.0;
  result["leven_score"] = fuzzyScore;
  
  QuizzerLogger.logMessage("$input => $comparison; Sim: $simScore, Fuzzy: $fuzzyScore");
  
  // Much stricter thresholds
  result["success"] = simScore >= 0.85 || fuzzyScore >= 0.92;
  
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


/// Validates a single string-based answer.
Future<bool> validateStringAnswer(String userAnswer, String correctAnswer) async {
  userAnswer = userAnswer.toLowerCase().trim();
  correctAnswer = correctAnswer.toLowerCase().trim();
  
  if (userAnswer == correctAnswer) {return true;}

  // Hard code list of validation
  if (userAnswer == "overfit" && correctAnswer == "overfitting") {return true;}
  if (userAnswer == "overfitt" && correctAnswer == "overfitting") {return true;}

  // Reject if word count differs significantly
  int userWords = userAnswer.split(RegExp(r'\s+')).length;
  int correctWords = correctAnswer.split(RegExp(r'\s+')).length;
  if ((userWords - correctWords).abs() > 1) return false;
  
  // Check known opposites/antonyms
  if (_areOpposites(userAnswer, correctAnswer)) return false;
  
  Map<String, dynamic> similarityResult = await isSimilarTo(userAnswer, correctAnswer);
  return similarityResult["success"];
}

bool _areOpposites(String a, String b) {
  final opposites = [
    ['hydrophilic', 'hydrophobic'],
    ['polar', 'nonpolar'],
    ['endergonic', 'exergonic'],
    ['positively', 'negatively'],
    ['increases', 'decreases'],
    ['covalent', 'noncovalent'],
    ['dna', 'rna'],
    ['anaphase', 'telophase', 'metaphase', 'prophase', 'interphase'],
    ['transcription', 'translation'],
    ['adhesion', 'cohesion'],
  ];
  
  for (var group in opposites) {
    if (group.contains(a) && group.contains(b) && a != b) return true;
  }
  return false;
}

Future<double> getFuzzyScoreForTypo(String userAnswer, String correctAnswer) async {
  return (fuzzy.ratio(userAnswer, correctAnswer) / 100.0);
}