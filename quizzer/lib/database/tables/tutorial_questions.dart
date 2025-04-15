// The tutorial questions table will follow the same design pattern as the question-answer pair table:
// You will not use classes for this table.
// You will follow the same design pattern as the question_answer_pairs table. and other database tables.
// There is no documentation for this table besides what I provide here.
// This will be curated hardcoded list of question-answer pairs designed only for the tutorial segment of the app.
// Since these are tutorial questions they only need an id marking it as a tutorial question: example:
// id: tutorial_01,
// The question and answer will be hardcoded for each tutorial question.
// The question and answer will not be stored in the question_answer_pairs table. Since it will be stored in this table.
// You will need to look at the home_page.dart file to examine the interface.
// The tutorial questions should address the following:
// - The center button on the home page is clickable so we should have a question prompt to the user to click the center button.
// - the button should then show the answer segement of the tutorial question with a "Good job" message, now press one of the buttons below to continue
// The next few tutorial questions should explain what each of the buttons are as described in the quizzer_documentation/Core Documentation/Chapter 03 - Research Methodology/03_06_Task_03_Answer_Questions.md behavioral task

// The next tutorial question should point out the flag icon and explain that the flag allows for notifying us that there is something wrong with a given question-answer pair

// The final tutorial question should address the menu button and prompt the user to explore a bit.

// Notice that our tutorial question will be displayed in the same way as the rest of the content, thus the wording of the question will need to be crafted to fit the context of the tutorial.
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/database/quizzer_database.dart';

// Table name
const String tableTutorialQuestions = 'tutorial_questions';

// Column names
const String columnId = 'id';
const String columnQuestion = 'question';
const String columnAnswer = 'answer';

// Create table SQL
const String createTutorialQuestionsTable = '''
  CREATE TABLE $tableTutorialQuestions (
    $columnId TEXT PRIMARY KEY,
    $columnQuestion TEXT NOT NULL,
    $columnAnswer TEXT NOT NULL
  )
''';

// Tutorial questions data
// The first tutorial question should very explicitly explain that the center button is where questions and answers are revealed.
// The first tutorial quesiton should also explain that Quizzer will be dynamically feeding them question-answer pairs to test their memory, explaining the basic premise of the app.

final Map<String, Map<String, String>> tutorialQuestions = {
  'tutorial_01': {
    'question': 'Welcome to Quizzer! This is a spaced repetition learning app that will not only help you memorize and learn information effectively, but also help you understand the information better. The center button is where you\'ll see questions and their answers. Questions will appear on the front, and when you\'re ready to check your answer, click the center button to reveal it. Try clicking the center button now to see how it works!',
    'answer': 'Good job! You\'ve just learned how to reveal answers. Quizzer will present you with question-answer pairs to test your memory, and based on your responses, it will determine when to show you each question again for optimal learning. Now try selecting one of the response buttons below to continue.',
  },
  'tutorial_02': {
    'question': 'Let\'s learn about the response buttons. The green buttons on the left are for "Yes" responses, while the red buttons on the right are for "No" responses. Each has a "sure" and "unsure" option. Try selecting one to continue.',
    'answer': 'Great! You\'ve learned about the response buttons. The "Yes(sure)" and "No(sure)" buttons are for when you\'re confident in your answer, while "Yes(unsure)" and "No(unsure)" are for when you\'re less certain.',
  },
  'tutorial_03': {
    'question': 'Notice the "Other" button in the middle? Click it to see additional response options.',
    'answer': 'Good! You\'ve discovered the "Other" options. These are for special cases like when you didn\'t read the question properly, find it too advanced, or just aren\'t interested in learning that topic. Select a response button to continue.',
  },
  'tutorial_04': {
    'question': 'Ok great, you\'re on a roll! See the flag icon in the top right? This is used to report issues with question-answer pairs. Try clicking it to see how it works.',
    'answer': 'Perfect! The flag feature lets you report any problems with questions, like incorrect answers, unclear wording, or inappropriate content. This helps us improve the quality of our content.',
  },
  'tutorial_05': {
    'question': 'Finally, check out the menu button in the top left. This is your gateway to all of Quizzer\'s features.',
    'answer': 'Excellent! The menu gives you access to settings, statistics, and other features. Feel free to explore and customize your Quizzer experience!',
  },
};

// Database helper methods
Future<void> createTutorialQuestionsTableIfNotExists() async {
  final Database db = await getDatabase();
  try {
    await db.execute(createTutorialQuestionsTable);
  } catch (e) {
    // Table already exists, ignore the error
    print('DEBUG: Tutorial questions table already exists');
  }
}

Future<void> insertTutorialQuestions() async {
  final Database db = await getDatabase();
  for (var entry in tutorialQuestions.entries) {
    await db.insert(
      tableTutorialQuestions,
      {
        columnId: entry.key,
        columnQuestion: entry.value['question']!,
        columnAnswer: entry.value['answer']!,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

Future<Map<String, String>?> getTutorialQuestion(String id) async {
  final Database db = await getDatabase();
  
  // First ensure the table exists
  await createTutorialQuestionsTableIfNotExists();
  
  // Check if the question exists
  final List<Map<String, dynamic>> maps = await db.query(
    tableTutorialQuestions,
    where: '$columnId = ?',
    whereArgs: [id],
  );

  // If the question doesn't exist, insert all tutorial questions
  if (maps.isEmpty) {
    await insertTutorialQuestions();
    
    // Try to get the question again after inserting
    final List<Map<String, dynamic>> newMaps = await db.query(
      tableTutorialQuestions,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (newMaps.isNotEmpty) {
      return {
        'question': newMaps.first[columnQuestion],
        'answer': newMaps.first[columnAnswer],
      };
    }
    return null;
  }

  return {
    'question': maps.first[columnQuestion],
    'answer': maps.first[columnAnswer],
  };
}

Future<List<Map<String, String>>> getAllTutorialQuestions(Database db) async {
  final List<Map<String, dynamic>> maps = await db.query(tableTutorialQuestions);
  return maps.map((map) => {
    'id': map[columnId] as String,
    'question': map[columnQuestion] as String,
    'answer': map[columnAnswer] as String,
  }).toList();
}
