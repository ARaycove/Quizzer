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
// For validation of short_answer and fill_in_the_blank questions
// additional fields for validation

Future<bool> validateShortAnswer() async{
  return false;
}

Future<bool> validateFillInTheBlank() async{
  return false;
}


TextAnalyzer analyzer = English.analyzer;

String normalizeString(String input){
  return input.trim().toLowerCase();
}

Future<List<String>> returnKeywords (String input) async{
  List<String> splitTerms = await analyzer.phraseSplitter(input);

  return splitTerms;
}


Future<List<String>> returnTerms (String input) async{
  List<String> termList = analyzer.termSplitter(input);

  return termList;
}

dynamic isSimilarTo(String input, String comparison) async{
  var output = input.similarityTo(comparison);

  return output;
}