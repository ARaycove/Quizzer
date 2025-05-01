import 'dart:io';
import 'dart:convert';
import 'dart:math';

// Simple class to hold relevant element data
class ElementData {
  final String name;
  final String symbol;
  final int atomicNumber;

  ElementData({
    required this.name,
    required this.symbol,
    required this.atomicNumber,
  });

  // Factory constructor to parse from the JSON map
  factory ElementData.fromJson(Map<String, dynamic> json) {
    // Add basic checks for required keys
    if (!json.containsKey('name') || !json.containsKey('symbol') || !json.containsKey('number')) {
      throw FormatException('Element JSON object is missing required keys (name, symbol, number). Found: ${json.keys}');
    }
    // Ensure atomic number is an int
    if (json['number'] is! int) {
       throw FormatException('Element atomic number (\'number\') must be an integer. Found: ${json['number'].runtimeType}');
    }
    return ElementData(
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      atomicNumber: json['number'] as int,
    );
  }

  // Method to format element for display in options/answers
  String get displayFormat => '$symbol - $name';

  // Method to format for options list expected by SessionManager
  Map<String, String> toOptionMap() {
      return {'type': 'text', 'content': displayFormat};
  }
}

Future<void> main() async {
  // Corrected relative path assuming script is run from project root (quizzer_v04/quizzer)
  final inputFile = File('runtime_cache/PeriodicTableJSON.json');
  final List<ElementData> allElements = [];
  final List<Map<String, dynamic>> generatedQuestions = [];
  final Random random = Random();
  const int numberOfQuestions = 200;
  const int elementsPerQuestion = 5;
  const String moduleName = 'periodic_table';
  const String questionType = 'sort_order';

  // --- 1. Read and Parse JSON Data ---
  try {
    if (!await inputFile.exists()) {
      print('Error: Input file not found at ${inputFile.path}');
      return;
    }
    final jsonString = await inputFile.readAsString();
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    if (!jsonData.containsKey('elements') || jsonData['elements'] is! List) {
       print('Error: JSON structure invalid. Expected root object with "elements" list.');
       return;
    }

    final List<dynamic> rawElements = jsonData['elements'] as List<dynamic>;

    for (final rawElement in rawElements) {
      if (rawElement is Map<String, dynamic>) {
        try {
          allElements.add(ElementData.fromJson(rawElement));
        } catch (e) {
          print('Warning: Skipping element due to parsing error: $e. Element data: $rawElement');
        }
      } else {
         print('Warning: Skipping non-map item in elements list: $rawElement');
      }
    }

    if (allElements.length < elementsPerQuestion) {
       print('Error: Not enough valid elements parsed (${allElements.length}) to generate questions requiring $elementsPerQuestion elements.');
       return;
    }

    print('Successfully parsed ${allElements.length} elements.');

  } catch (e) {
    print('Error reading or parsing JSON file: $e');
    return;
  }

  // --- 2. Generate Questions ---
  print('Generating $numberOfQuestions questions...');
  for (int i = 0; i < numberOfQuestions; i++) {
    // --- Select 5 distinct random elements ---
    final Set<int> selectedIndices = {};
    final List<ElementData> selectedElements = [];
    while (selectedElements.length < elementsPerQuestion) {
      final randomIndex = random.nextInt(allElements.length);
      // Ensure distinct elements
      if (selectedIndices.add(randomIndex)) {
        selectedElements.add(allElements[randomIndex]);
      }
    }

    // --- Determine sort order and instruction text ---
    final bool sortByDescending = i < (numberOfQuestions / 2); // First 100 descending, next 100 ascending
    final String sortInstruction = sortByDescending ? 'highest to lowest' : 'lowest to highest';
    final String questionText = 'Sort the following elements by atomic number ($sortInstruction):';

    // --- Sort the selected elements for the correct answer ---
    selectedElements.sort((a, b) {
      return sortByDescending
          ? b.atomicNumber.compareTo(a.atomicNumber) // Descending
          : a.atomicNumber.compareTo(b.atomicNumber); // Ascending
    });

    // --- Create question elements ---
    final List<Map<String, String>> questionElements = [
      {'type': 'text', 'content': questionText}
    ];

    // --- Create answer elements (explanation) ---
    final String explanation = 'The correct order by atomic number ($sortInstruction) is:\n' +
        selectedElements.map((e) => '${e.displayFormat} (Atomic #: ${e.atomicNumber})').join('\n');
    final List<Map<String, String>> answerElements = [
      {'type': 'text', 'content': explanation}
    ];

    // --- Create options list (correctly ordered list of element maps) ---
    final List<Map<String, String>> options = selectedElements.map((e) => e.toOptionMap()).toList();

    // --- Assemble question data map for SessionManager.addNewQuestion ---
    final Map<String, dynamic> questionData = {
      'questionType': questionType,
      'moduleName': moduleName,
      'questionElements': questionElements, // List<Map<String, String>>
      'answerElements': answerElements,   // List<Map<String, String>>
      'options': options,                // List<Map<String, String>> - CORRECTLY ORDERED elements for sorting
    };

    generatedQuestions.add(questionData);
  }

  // --- 3. Output JSON ---
  print('Generation complete. Outputting JSON...');
  final jsonOutputString = const JsonEncoder.withIndent('  ').convert(generatedQuestions);

  // Write to a file:
  final outputFile = File('runtime_cache/generated_periodic_table_sort_questions.json');
  await outputFile.writeAsString(jsonOutputString);
  print('JSON data also written to ${outputFile.path}');
}
