import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_validation_functionality.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

void main() async {
  await QuizzerLogger.setupLogging();
  
  // // Phrases defined at top for reuse across tests
  // List<String> phrases = [

    
    
    
    
  // ];
  
  // // 5 new reconstructed/reworded phrases
  // List<String> reconstructedPhrases = [
  // ];
  
  // List<String> questions = [
  //   'the lazy dog had a quick brown fox jump over him.',
  //   'The quick brown fox jumps over the lazy dog.',
  //   'The powerhouse of the cell is mitochondria.',
  //   'Mitochondria are the powerhouse of the cell.',
  //   'The process of photosynthesis requires sunlight to make glucose.',
  //   'Photosynthesis converts sunlight into glucose.',
  //   'Genetic information is stored in DNA',
  //   'DNA contains genetic information.',
  //   'In order to catalyze biochemical reactions, enzymes are required.',
  //   'Enzymes catalyze biochemical reactions.',
  //   'What is the capital of France?',
  //   'How does photosynthesis work?',
  //   'When did World War II end?',
  //   'Who wrote Romeo and Juliet?',
  //   'Where is the Great Wall of China located?',
  //   'Why do leaves change color in autumn?',
  //   'Which planet is closest to the sun?',
  //   'How many bones are in the human body?',
  //   'What causes earthquakes?',
  //   'Who discovered penicillin?'
  // ];
  
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
      print('${'Term'.padRight(termWidth)} | ${'Typo'.padRight(typoWidth)} | ${'Sim Score'.padRight(simScoreWidth)} | ${'Leven Score'.padRight(levenScoreWidth)} | ${'Bool'.padRight(boolWidth)} |');
      // Divider
      print('${''.padRight(termWidth, '-')} | ${''.padRight(typoWidth, '-')} | ${''.padRight(simScoreWidth, '-')} | ${''.padRight(levenScoreWidth, '-')} | ${''.padRight(boolWidth, '-')} |');
      print(table);
    });
  });
  group('Test 2: validation unit testing', () {
    // correct/correctly spelled
    Map<String, dynamic> correctAttempts = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["enzyme", "mitochondria", "photosynthesis", "nucleus", "cytoplasm"]
    };

    // Answers are correct, but mispelled
    Map<String,dynamic> typoCorrectAttempts = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["enyzme", "mitochondira", "photosyntheis", "nucleas", "cytoplasam"]
    };

    // Answers are synonyms provided, but not primary answer
    Map<String, dynamic> synonymCorrectAttempts = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["catalyze", "powerhouse", "light reaction", "control center", "cell fluid"]
    };

    // Answers are not correct
    Map<String, dynamic> inCorrectAttempts = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["protein", "ribosome", "respiration", "membrane", "vacuole"]
    };

    // Answers are partially correct (some are right some are wrong)
    Map<String, dynamic> partiallyCorrectAttempts = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["enzyme", "protein", "photosynthesis", "membrane", "cytoplasm"]
    };

    // too many answers
    Map<String, dynamic> invalidDataOne = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]}
      ],
      "user_answers": ["enzyme", "mitochondria", "photosynthesis", "extra_answer", "another_extra"]
    };

    // not enough answers
    Map<String, dynamic> invalidDataTwo = {
      "answers_to_blanks": [
        {"enzyme": ["catalyze", "catalyzes", "catalyzing"]},
        {"mitochondria": ["powerhouse", "energy factory", "cellular power plant"]},
        {"photosynthesis": ["light reaction", "solar energy conversion", "plant food making"]},
        {"nucleus": ["control center", "brain of cell", "genetic headquarters"]},
        {"cytoplasm": ["cell fluid", "cellular matrix", "intracellular space"]}
      ],
      "user_answers": ["enzyme", "mitochondria"]
    };

    test('correct attempts should pass validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": correctAttempts["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, correctAttempts["user_answers"]);
      
      expect(result["isCorrect"], true);
      expect(result["ind_blanks"], [true, true, true, true, true]);
    });

    test('typo correct attempts should pass validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": typoCorrectAttempts["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, typoCorrectAttempts["user_answers"]);
      
      expect(result["isCorrect"], true);
      expect(result["ind_blanks"], [true, true, true, true, true]);
    });

    test('synonym correct attempts should pass validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": synonymCorrectAttempts["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, synonymCorrectAttempts["user_answers"]);
      
      expect(result["isCorrect"], true);
      expect(result["ind_blanks"], [true, true, true, true, true]);
    });

    test('incorrect attempts should fail validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": inCorrectAttempts["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, inCorrectAttempts["user_answers"]);
      
      expect(result["isCorrect"], false);
      expect(result["ind_blanks"], [false, false, false, false, false]);
    });

    test('partially correct attempts should show mixed results', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": partiallyCorrectAttempts["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, partiallyCorrectAttempts["user_answers"]);
      
      expect(result["isCorrect"], false);
      expect(result["ind_blanks"], [true, false, true, false, true]);
    });

    test('too many answers should fail validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": invalidDataOne["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, invalidDataOne["user_answers"]);
      
      expect(result["isCorrect"], false);
      expect(result["ind_blanks"], [false, false, false]);
    });

    test('not enough answers should fail validation', () async {
      Map<String, dynamic> questionData = {
        "question_type": "fill_in_the_blank",
        "answers_to_blanks": invalidDataTwo["answers_to_blanks"]
      };
      
      Map<String, dynamic> result = await validateFillInTheBlank(questionData, invalidDataTwo["user_answers"]);
      
      expect(result["isCorrect"], false);
      expect(result["ind_blanks"], [false, false, false, false, false]);
    });
  });
}

