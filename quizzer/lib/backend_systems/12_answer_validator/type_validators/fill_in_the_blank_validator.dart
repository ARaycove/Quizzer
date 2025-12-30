// import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/text_analysis_tools.dart';
// import 'package:quizzer/backend_systems/12_answer_validator/answer_validation/math_validation.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:math_keyboard/math_keyboard.dart';


// class FillInTheBlankValidator {
//   static final FillInTheBlankValidator _instance = FillInTheBlankValidator._internal();
//   factory FillInTheBlankValidator() => _instance;
//   FillInTheBlankValidator._internal();
//   // ==================================================
//   // ----- Constants -----
//   // ==================================================
//   static final Set<String> _exactEvalCases = {
//   "==", "!=", "isdigit()", "++",'System.out.println("Hello, World");', "a'b", "sudo dpkg -i filename.deb",
//   "java example one two three", "boolean myValue = true;", "int[][] twoD_arr = new int[10][20];"
//   };
//   static final Set<String> _typoCheckOnlyCases = {
//   "endosymbiosis", "stromatolites", "generalized linear model", "adenosine triphosphate",
//   "cumulative distribution function", "probability density", "prior probability", "charged", "uncharged",
//   "positively", "negatively"
//   };
// }