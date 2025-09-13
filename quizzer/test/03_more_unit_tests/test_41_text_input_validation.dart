import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_validation_functionality.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_analysis_tools.dart';
void main() async {
  await QuizzerLogger.setupLogging();
  
  group('Test 1: Similarity scoring', () {
    List<List<String>> testData = [
      ["enzyme", "enyzme"],
      ["mitochondria", "mitochondira"],
      ["photosynthesis", "photosyntheis"],
      ["chlorophyll", "chlorophyl"],
      ["nucleus", "nucleas"],
      ["cytoplasm", "cytoplasam"],
      ["ribosome", "ribosme"],
      ["endoplasmic", "endoplasic"],
      ["reticulum", "reticulm"],
      ["lysosome", "lysosme"],
      ["vacuole", "vacuol"],
      ["chromosome", "chromosme"],
      ["deoxyribonucleic", "deoxyribonuclic"],
      ["adenosine", "adenosne"],
      ["triphosphate", "triphospate"],
      ["glycolysis", "glycolyis"],
      ["fermentation", "fementaion"],
      ["respiration", "resperation"],
      ["metabolism", "metabolis"],
      ["catalysis", "catalyis"],
      ["substrate", "substrte"],
      ["activation", "activaton"],
      ["inhibition", "inhibton"],
      ["diffusion", "difusion"],
      ["osmosis", "osmosi"]
    ];
    
    test('testData should be correct', () async {

      
      String table = "";
      // Column widths
      int termWidth = 20;
      int typoWidth = 20;
      int simScoreWidth = 10;
      int levenScoreWidth = 12;
      int boolWidth = 5;

      
      for (List<String> group in testData) {
        Map<String, dynamic> result = await isSimilarTo(group[0], group[1]);
        expect(result["success"], true);
        
        String term = group[0].padRight(termWidth);
        String typo = group[1].padRight(typoWidth);
        String simScore = (result["sim_score"]?.toStringAsFixed(3) ?? "null").padRight(simScoreWidth);
        String levenScore = (result["leven_score"]?.toStringAsFixed(1) ?? "null").padRight(levenScoreWidth);
        String boolResult = result["success"].toString().padRight(boolWidth);
        
        table += '$term | $typo | $simScore | $levenScore | $boolResult |\n';
      }
      // Header
      QuizzerLogger.logMessage('${'Term'.padRight(termWidth)} | ${'Typo'.padRight(typoWidth)} | ${'Sim Score'.padRight(simScoreWidth)} | ${'Leven Score'.padRight(levenScoreWidth)} | ${'Bool'.padRight(boolWidth)} |');
      // Divider
      QuizzerLogger.logMessage('${''.padRight(termWidth, '-')} | ${''.padRight(typoWidth, '-')} | ${''.padRight(simScoreWidth, '-')} | ${''.padRight(levenScoreWidth, '-')} | ${''.padRight(boolWidth, '-')} |');
      QuizzerLogger.logMessage(table);
    });
  });
  group('Test 2: validation unit testing', () {
    // Data Structure is a table:
    // [answers to blanks, "provided answer", "expected"] // Comment as to why
    // [List<Map<String, List<dynamic>>>, List<String>, bool]

    List<List<dynamic>> validationCases = [
      // Correct cases:
      [[{"enzyme": ["catalyze", "catalyzes", "catalyzing"]}],                                     ["enzyme"],         true],
      [[{"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]}],              ["mitochondria"],   true],
      [[{"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}],  ["photosynthesis"], true],
      [[{"nucleus": ["control center", "brain of cell", "genetic headquarters"]}],                ["nucleus"],        true],
      [[{"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}],                 ["cytoplasm"],      true],
      // Typos
      [[{"enzyme": ["catalyze", "catalyzes", "catalyzing"]}],                                     ["enyzme"],         true],
      [[{"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]}],              ["mitochondira"],   true],
      [[{"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}],  ["photosyntheis"],  true],
      [[{"nucleus": ["control center", "brain of cell", "genetic headquarters"]}],                ["nucleas"],        true],
      [[{"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}],                 ["ctyoplasam"],     true],
      [[{"collisions": [""]}], ["collissions"], true],
      // Handle cases where synonym is provided
      [[{"enzyme": ["catalyze", "catalyzes", "catalyzing"]}],                                     ["catalyze"],       true],
      [[{"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]}],              ["powerhouse"],                 true],
      [[{"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}],  ["light reaction"],             true],
      [[{"nucleus": ["control center", "brain of cell", "genetic headquarters"]}],                ["control center"],             true],
      [[{"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}],                 ["cell fluid"],                 true],
      // Handle cases where wrong answer is provided
      [[{"enzyme": ["catalyze", "catalyzes", "catalyzing"]}],                                     ["protein"],                    false],
      [[{"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]}],              ["ribosome"],                   false],
      [[{"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}],  ["respiration"],                false],
      [[{"nucleus": ["control center", "brain of cell", "genetic headquarters"]}],                ["membrane"],                   false],
      [[{"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}],                 ["vacuole"],                    false],
      [[{"generalized linear model": [""]}],                                                      ["generalized additive model"], false],


      [[{"stromatolites": [""]}], ["stalactomites"],  false],
      [[{"endosymbiosis": [""]}], ["endocytosis"],    false],
      // Too many answers provided (interface should prevent this)
      [[{"enzyme": ["catalyze", "catalyzes", "catalyzing"]},{"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},{"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}], 
      ["enzyme", "mitochondria", "photosynthesis", "extra_answer", "another_extra"], 
      false],
      // Not enough answers provided:
      [[
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ], ["enzyme", "mitochondria"], false],
      [[{"evaporative cooling": [""]}], ["evaporation"], false],
      // These cases are explicitely wrong, even though they would pass a basic typo check
      [[{"positively": [""]}], ["negatively"], false],
      [[{"negatively": [""]}], ["positively"], false],
      [[{"charged": [""]}], ["uncharged"], false],
      [[{"uncharged": [""]}], ["charged"], false], 
      [[{"asexual reproduction": [""]}], ["sexual reproduction"], false], 
      [[{"sexual reproduction": [""]}], ["asexual reproduction"], false],
      // passes similarity check, but still not correct answer
      [[{"carbonic acid": [""]}], ["carbonate"], false],
      [[{"hydrogen bonds": [""]}], ["bonds"], false], // Answer contains part of the correct response but is incomplete and thus should not pass validation (perhaps a simple ensure the provided answer is the same number of words heuristic?)
      [[{"closed system": [""]}], ["system"], false], // incomple answer, not quite correct, should not pass
      [[{"every element": [""]}], ["all elements", true]], // semantically the same both contains the core meaning (all components of elements)

    ];

    test('Cases should all validate correctly', () async {
      for (int i = 0; i < validationCases.length; i++) {
        // Construct mock question data map for testing
        Map<String, dynamic> questionData = {
          "question_type": "fill_in_the_blank",
          "answers_to_blanks": validationCases[i][0] // 0 index is the correct answers
        };
        List<String> userAnswers = validationCases[i][1];
        bool expectedResult = validationCases[i][2];

        Map<String, dynamic> result = await validateFillInTheBlank(questionData, userAnswers);
        QuizzerLogger.logMessage("Testing case $i => ${validationCases[i][0]} with provided Answer: $userAnswers");
        QuizzerLogger.logMessage("Result: $result vs Expected: $expectedResult");
        expect(result["isCorrect"], expectedResult);
        // // Check that all individual blank results match the expected result
        // expect(result["ind_blanks"].every((element) => element == expectedResult), true);
        QuizzerLogger.logMessage("_" * 50);
      }
    });
  });
}

