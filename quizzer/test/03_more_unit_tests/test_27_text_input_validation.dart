import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/session_manager/answer_validation/text_validation_functionality.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

void main() async {
  await QuizzerLogger.setupLogging();
  
  List<String> questions = [
    'What is the capital of France?',
    'How does photosynthesis work?',
    'When did World War II end?',
    'Who wrote Romeo and Juliet?',
    'Where is the Great Wall of China located?',
    'Why do leaves change color in autumn?',
    'Which planet is closest to the sun?',
    'How many bones are in the human body?',
    'What causes earthquakes?',
    'Who discovered penicillin?'
  ];
  
  group('Test 1: Combined Analysis', () {
    test('should extract keywords from input', () async {
      List<String> result = await returnKeywords('Hello world this is a test');
      expect(result, isA<List<String>>());
    });

    test('compare keywords vs terms', () async {
      QuizzerLogger.logMessage('Question | Keywords | Terms');
      QuizzerLogger.logMessage('---------|----------|------');
      
      for (String question in questions) {
        List<String> keywords = await returnKeywords(question);
        List<String> terms = await returnTerms(question);
        
        String keywordStr = keywords.join(', ');
        String termStr = terms.join(', ');
        
        QuizzerLogger.logMessage('$question | $keywordStr | $termStr');
      }
    });
  });

  group('Test 2: Similarity Analysis', () {
    test('compare synonymous words', () async {
      List<String> words = ['glucose', 'sugar', 'carbohydrate', 'city', 'metropolis'];
      
      QuizzerLogger.logMessage('Word 1 | Word 2 | Similarity Score');
      QuizzerLogger.logMessage('--------|--------|----------------');
      
      for (int i = 0; i < words.length; i++) {
        for (int j = i + 1; j < words.length; j++) {
          double similarity = await isSimilarTo(words[i], words[j]);
          QuizzerLogger.logMessage('${words[i]} | ${words[j]} | $similarity');
        }
      }
    });
  });
}
