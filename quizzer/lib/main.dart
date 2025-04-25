import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/add_question_answer_page.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/display_modules_page.dart';
import 'package:quizzer/UI_systems/01_new_user_page/new_user_page.dart';
import 'package:quizzer/UI_systems/00_login_page/login_page.dart';
import 'package:quizzer/UI_systems/02_home_page/home_page.dart';
import 'package:quizzer/UI_systems/05_menu_page/menu_page.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:logging/logging.dart'; // Import logging package
// List to do items, major projects and implementation (order by priority)

// TODO add_question_page should have live preview


// TODO Create new async worker that maintains a list of eligible questions and caches questions that won't be up for review until much later
// - This worker should cut down on the total amount of calculations necessary for the selection worker
// TODO Optimize question selection loop (see file)

// TODO Add additional question types and validation:
// General Process
// // Backend updates
// Determine data structure and custom fields for type
// update in question_answer_pairs table
// update answer submission with appropriate check and answer correctness validation
// // UI updates
// create widget for UI display
// update home_page to use new widget
// update add_question_answer_pairs with new type selection and form fields
// update add_question_answer_pairs with validation of new elements
// update bulk-add function to accomadate new type

  // Question Types (Questions have different potential types)
  // // 2. sort_order
  // //   [X] Define Data Structure & Schema
  // - Will have a correct order field -> [0, 1, 4, 2, 3]
  // This correct_order field will use the same schema as the question-answer elements fields {type: content, type: content: . . .}
  // Question order items will be presented in a randomized order (if it is randomized correctly we will shuffle again)
  // User then reorders them
  // Validation is by checking the ordered string against what the user ordered.

  // //   [X] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // - add function
  // - edit function (null check)
  // - schema verification
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // When entering the correct order will be what is submitted, when validating if correct we check to see if the elements presented have been ordered in the same way they were entered

  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 3. true_false
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 4. matching
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 5. fill_in_the_blank
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 6. short_answer
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 7. hot_spot (click correct location on an image)
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 8. label_diagram (drag and drop)
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests
  // // 9. math (complex widget to allow for entering mathematical inputs)
  // //   [ ] Define Data Structure & Schema
  // //   [ ] Update DB Schema Validation (`question_answer_pairs_table.dart`)
  // //   [ ] Update `SessionManager.submitAnswer` Logic
  // //   [ ] Update Bulk Add Function (`widget_bulk_add_button.dart`)
  // //   [ ] Create Display Widget (`UI_systems/02_home_page/`)
  // //   [ ] Update `home_page` Switch
  // //   [ ] Update Type Selection (`widget_question_type_selection.dart`)
  // //   [ ] Create Input Widget(s) (`UI_systems/03_add_question_page/`)
  // //   [ ] Update `add_question_answer_page` (Show Input, Validate Form)
  // //   [ ] Update Live Preview Widget (`widget_live_preview.dart`)
  // //   [ ] Generate Test Data (`test/util/`)
  // //   [ ] Write Unit/Widget Tests


// TODO update multiple choice widget to randomize order of options when presented (visually)
// TODO Allow for editing questions from module page
// TODO Implement EDIT question button and page on home_page



// Items that can wait for right before launch
// TODO Implement cloud database and sync amongst database
// TODO Windows Test
// TODO MacOs Test
// TODO IOS Test
// TODO user role authentication -> will determine whether user can edit questions or add them
// - (can be implemented right before launch)

// Import for platform-specific initialization
import 'main_native.dart' if (dart.library.html) 'main_web.dart' as platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- Setup Logging ---
  // Set log level based on mode (more verbose in debug)
  final logLevel = kDebugMode ? Level.INFO : Level.WARNING;
  QuizzerLogger.setupLogging(level: logLevel);
  // ---------------------

  // Initialize Hive based on platform
  await platform.initializeHive();
  
  // Optional: Register Adapters here if needed later
  // Hive.registerAdapter(YourAdapter()); 

  runApp(const QuizzerApp());
}

class QuizzerApp extends StatelessWidget {  
  const QuizzerApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login':           (context) => const LoginPage(),
        // '/home':            (context) => const HomePage(), //FIXME need to add in HomePage fix
        '/menu':            (context) => const MenuPage(),
        '/add_question':    (context) => const AddQuestionAnswerPage(),
        '/display_modules': (context) => const DisplayModulesPage(),
        '/signup':          (context) => const NewUserPage(),
      },
    );
  }
}

// Completed Items!
// (complete) Bulk add questions to the database


// Question Types (Questions have different potential types)
// 1. multiple_choice                                                   (complete)