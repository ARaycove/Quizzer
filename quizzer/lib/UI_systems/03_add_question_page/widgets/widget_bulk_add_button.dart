import 'dart:convert';
import 'dart:io'; // For File operations (non-web)
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

// switch statement handler inside main _handleBulkAdd function

// 1. Pick a json file with a list of questions to add
// 2. Iterate over each question map
// 3. determine the type
// 4. add and validate based on type

// ==========================================
// Widget for the bulk add button
// ==========================================

class BulkAddButton extends StatefulWidget {
  const BulkAddButton({super.key});

  @override
  State<BulkAddButton> createState() => _BulkAddButtonState();
}

class _BulkAddButtonState extends State<BulkAddButton> {
  bool _isLoading = false;
  final SessionManager _session = getSessionManager();

  Future<void> _handleBulkAdd(BuildContext context) async {
    setState(() => _isLoading = true);
    String? selectedFileName; // To store filename for logging
    int itemsProcessed = 0; // Renamed from itemsAttempted
    int itemsSkipped = 0;
    int itemsAdded = 0; // Track successful additions via API call completion

    // 1. Pick JSON file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null) {
      QuizzerLogger.logMessage('Bulk Add: File picking cancelled by user.');
      setState(() => _isLoading = false);
      return; // User cancelled picker
    }

    // Ensure platform file path is available (will be null on web without specific handling)
    final path = result.files.single.path;
    selectedFileName = result.files.single.name;
    QuizzerLogger.logMessage('Bulk Add: User selected file: $selectedFileName');

    if (path == null) {
       QuizzerLogger.logError('Bulk Add: File path is null. This method currently only supports non-web platforms.');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Error: File path not available (Web platform not fully supported by this method yet).'), backgroundColor: ColorWheel.buttonError),
        );
        setState(() => _isLoading = false);
        return;
    }

    // 2. Read File Content (non-web only for now)
    final file = File(path);
    final String fileContent = await file.readAsString(); // Errors will propagate
    QuizzerLogger.logMessage('Bulk Add: File content read successfully for $selectedFileName.');

    // 3. Decode JSON - Errors will propagate (Fail Fast)
    final decodedJson = jsonDecode(fileContent);

    // 4. Basic structure check: Ensure it's a List
    assert(decodedJson is List, 'Bulk Add Error: Expected JSON root to be a List, but got ${decodedJson.runtimeType}. Aborting.');
    final List<dynamic> questionList = decodedJson as List<dynamic>;
    QuizzerLogger.logMessage('Bulk Add: JSON decoded successfully. Found ${questionList.length} potential questions in $selectedFileName.');

    // 5. Iterate and Add Questions with Pre-validation
    for (int i = 0; i < questionList.length; i++) {
      final item = questionList[i];
      final itemNumber = i + 1; // 1-based index for logging
      itemsProcessed++; // Count item being looked at

      // --- Start Pre-Validation ---
      // Basic check: Is item a Map?
      if (item is! Map) {
        QuizzerLogger.logWarning('Bulk Add: Item $itemNumber in $selectedFileName is not a valid JSON object (Map). Skipping.');
        itemsSkipped++;
        continue;
      }
      final Map<String, dynamic> questionMap = Map<String, dynamic>.from(item); // Ensure String keys

      // Check required common fields
      final String? moduleName = questionMap['moduleName'] as String?;
      final String? questionType = questionMap['questionType'] as String?;
      final List<dynamic>? questionElementsRaw = questionMap['questionElements'] as List?;
      final List<dynamic>? answerElementsRaw = questionMap['answerElements'] as List?;

      if (moduleName == null || moduleName.isEmpty) {
        QuizzerLogger.logWarning('Bulk Add: Item $itemNumber missing or empty "moduleName". Skipping.');
        itemsSkipped++; continue;
      }
      if (questionType == null || questionType.isEmpty) {
        QuizzerLogger.logWarning('Bulk Add: Item $itemNumber missing or empty "questionType". Skipping.');
        itemsSkipped++; continue;
      }

      // Validate Elements structure (basic check)
      List<Map<String, dynamic>>? questionElements = _validateElements(questionElementsRaw);
      if (questionElements == null) {
        QuizzerLogger.logWarning('Bulk Add: Item $itemNumber has invalid "questionElements". Skipping.');
        itemsSkipped++; continue;
      }
      List<Map<String, dynamic>>? answerElements = _validateElements(answerElementsRaw);
      if (answerElements == null) {
        QuizzerLogger.logWarning('Bulk Add: Item $itemNumber has invalid "answerElements". Skipping.');
        itemsSkipped++; continue;
      }

      // Type-Specific Validation
      List<Map<String, dynamic>>? options;
      int? correctOptionIndex;
      List<int>? indexOptionsThatApply;

      switch (questionType) {
        case 'multiple_choice':
          final validationResult = _validateMultipleChoice(questionMap);
          if (validationResult['error'] != null) {
            QuizzerLogger.logWarning('Bulk Add: Item $itemNumber (multiple_choice) invalid: ${validationResult['error']}. Skipping.');
            itemsSkipped++; continue;
          }
          options = validationResult['options'];
          correctOptionIndex = validationResult['correctOptionIndex'];
          break;

        case 'select_all_that_apply':
          final validationResult = _validateSelectAll(questionMap);
           if (validationResult['error'] != null) {
            QuizzerLogger.logWarning('Bulk Add: Item $itemNumber (select_all) invalid: ${validationResult['error']}. Skipping.');
            itemsSkipped++; continue;
          }
          options = validationResult['options'];
          indexOptionsThatApply = validationResult['indexOptionsThatApply'];
          break;

         case 'true_false':
            final validationResult = _validateTrueFalse(questionMap);
            if (validationResult['error'] != null) {
              QuizzerLogger.logWarning('Bulk Add: Item $itemNumber (true_false) invalid: ${validationResult['error']}. Skipping.');
              itemsSkipped++; continue;
            }
            correctOptionIndex = validationResult['correctOptionIndex'];
            // Options are implicitly True/False, not needed from JSON for this type usually
            options = [{'type': 'text', 'content': 'True'}, {'type': 'text', 'content': 'False'}];
           break;

         case 'sort_order':
            final validationResult = _validateSortOrder(questionMap);
            if (validationResult['error'] != null) {
              QuizzerLogger.logWarning('Bulk Add: Item $itemNumber (sort_order) invalid: ${validationResult['error']}. Skipping.');
              itemsSkipped++; continue;
            }
            // API expects 'options' for sort order items
            options = validationResult['options'];
           break;

        // Add cases for other supported types...
        default:
          QuizzerLogger.logWarning('Bulk Add: Item $itemNumber has unsupported questionType "$questionType". Skipping.');
          itemsSkipped++; continue;
      }
      // --- End Pre-Validation ---

      QuizzerLogger.logMessage('Bulk Add: Validation passed for item $itemNumber. Calling API...');

      // 6. Call SessionManager to Add - Errors will propagate and stop the process (Fail Fast)
      await _session.addNewQuestion(
        questionType: questionType, // Already validated non-null/empty
        moduleName: moduleName,     // Already validated non-null/empty
        questionElements: questionElements, // Already validated non-null
        answerElements: answerElements,     // Already validated non-null
        options: options,                   // Validated per type
        correctOptionIndex: correctOptionIndex, // Validated per type
        indexOptionsThatApply: indexOptionsThatApply, // Validated per type
        // Optional fields from map
        citation: questionMap['citation'] as String?,
        concepts: questionMap['concepts'] as String?,
        subjects: questionMap['subjects'] as String?,
      );

      itemsAdded++; // Increment only if API call succeeds
      QuizzerLogger.logSuccess('Bulk Add: Successfully added item $itemNumber from $selectedFileName.');

    } // End of loop

    // 7. Simple Completion Log
    QuizzerLogger.logMessage('Bulk Add: Process finished for $selectedFileName. Items processed: $itemsProcessed, Added: $itemsAdded, Skipped (invalid format/data): $itemsSkipped.');

    // Optional: Show completion SnackBar
    if (mounted) { // Guard with mounted check
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('Bulk add finished for $selectedFileName. Added $itemsAdded, Skipped $itemsSkipped.'),
          backgroundColor: itemsSkipped > 0 ? ColorWheel.buttonError : ColorWheel.buttonSuccess,
        ),
      );
    }

    setState(() => _isLoading = false); // Ensure loading state is turned off
  }

  // --- Helper Validation Functions ---

  List<Map<String, dynamic>>? _validateElements(List<dynamic>? elementsRaw) {
    if (elementsRaw == null || elementsRaw.isEmpty) return null;
    final List<Map<String, dynamic>> validElements = [];
    for (final element in elementsRaw) {
      if (element is Map &&
          element['type'] is String &&
          element['content'] is String &&
          (element['type'] as String).isNotEmpty &&
          (element['content'] as String).isNotEmpty) {
        validElements.add(Map<String, dynamic>.from(element));
      } else {
        return null; // Invalid structure found
      }
    }
    return validElements;
  }

   Map<String, dynamic> _validateMultipleChoice(Map<String, dynamic> questionMap) {
        final List<dynamic>? optionsRaw = questionMap['options'] as List?;
        final dynamic correctIndexRaw = questionMap['correctOptionIndex'];

        if (optionsRaw == null || optionsRaw.isEmpty) {
      return {'error': 'Missing or empty "options" list'};
    }
     // Ensure options are converted correctly
    final List<Map<String, dynamic>> options = optionsRaw.map((o) {
        if (o is Map) return Map<String, dynamic>.from(o);
        return {'type': 'text', 'content': o.toString()};
    }).toList();

        if (correctIndexRaw == null) {
      return {'error': 'Missing "correctOptionIndex"'};
        }
    int? correctOptionIndex;
        if (correctIndexRaw is int) {
          correctOptionIndex = correctIndexRaw;
        } else if (correctIndexRaw is String) {
          correctOptionIndex = int.tryParse(correctIndexRaw);
        }
        if (correctOptionIndex == null || correctOptionIndex < 0 || correctOptionIndex >= options.length) {
      return {'error': 'Invalid "correctOptionIndex" (value: $correctIndexRaw, options count: ${options.length})'};
    }
    return {'options': options, 'correctOptionIndex': correctOptionIndex};
  }

  Map<String, dynamic> _validateSelectAll(Map<String, dynamic> questionMap) {
    final List<dynamic>? optionsRaw = questionMap['options'] as List?;
    final List<dynamic>? indicesRaw = questionMap['indexOptionsThatApply'] as List?;

    if (optionsRaw == null || optionsRaw.isEmpty) {
      return {'error': 'Missing or empty "options" list'};
    }
     // Ensure options are converted correctly
    final List<Map<String, dynamic>> options = optionsRaw.map((o) {
        if (o is Map) return Map<String, dynamic>.from(o);
        return {'type': 'text', 'content': o.toString()};
    }).toList();


    if (indicesRaw == null || indicesRaw.isEmpty) {
      return {'error': 'Missing or empty "indexOptionsThatApply" list'};
    }
    final List<int> validIndices = [];
    for (final indexRaw in indicesRaw) {
      int? index;
      if (indexRaw is int) {
        index = indexRaw;
      } else if (indexRaw is String) {
        index = int.tryParse(indexRaw);
      }
      if (index == null || index < 0 || index >= options.length) {
        return {'error': 'Invalid index $indexRaw found in "indexOptionsThatApply" (options count: ${options.length})'};
      }
      if (!validIndices.contains(index)) { // Avoid duplicates
          validIndices.add(index);
      }
    }
     if (validIndices.isEmpty) { // Ensure at least one valid index resulted
       return {'error': '"indexOptionsThatApply" list resulted in no valid indices'};
     }
    validIndices.sort(); // Ensure consistent order if needed by API
    return {'options': options, 'indexOptionsThatApply': validIndices};
  }

   Map<String, dynamic> _validateTrueFalse(Map<String, dynamic> questionMap) {
      final dynamic correctIndexRaw = questionMap['correctOptionIndex'];
       if (correctIndexRaw == null) {
         return {'error': 'Missing "correctOptionIndex"'};
       }
      int? correctOptionIndex;
      if (correctIndexRaw is int) {
        correctOptionIndex = correctIndexRaw;
      } else if (correctIndexRaw is String) {
        correctOptionIndex = int.tryParse(correctIndexRaw);
      }
       if (correctOptionIndex == null || (correctOptionIndex != 0 && correctOptionIndex != 1)) {
         return {'error': 'Invalid "correctOptionIndex" for true_false (must be 0 or 1, got: $correctIndexRaw)'};
       }
      return {'correctOptionIndex': correctOptionIndex};
   }

   Map<String, dynamic> _validateSortOrder(Map<String, dynamic> questionMap) {
      final List<dynamic>? optionsRaw = questionMap['options'] as List?; // API expects 'options' for sortable items
      if (optionsRaw == null || optionsRaw.isEmpty) {
        return {'error': 'Missing or empty "options" list (required for sort_order items)'};
      }
      // Ensure options are converted correctly
      final List<Map<String, dynamic>> options = optionsRaw.map((o) {
          if (o is Map) return Map<String, dynamic>.from(o);
          return {'type': 'text', 'content': o.toString()};
      }).toList();

      if (options.length < 2) { // Need at least 2 items to sort
        return {'error': 'Sort order questions require at least 2 options'};
      }

      return {'options': options}; // Return the formatted options
  }

  // --- 
  // Build Method
  // ---

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
            icon: _isLoading 
                  ? const SizedBox( // Replace icon with progress indicator
                      width: 18, height: 18, // Smaller size for button
                      child: CircularProgressIndicator(
                        color: ColorWheel.primaryText, // Text color for contrast
                        strokeWidth: 2.0,
                      )
                    )
                  : const Icon(Icons.upload_file, size: 18.0), // Standard icon
            label: const Text('Bulk Add'),
            style: ElevatedButton.styleFrom(
               backgroundColor: ColorWheel.secondaryBackground, // Use secondary background for gray
               foregroundColor: ColorWheel.primaryText, // Text/Icon color
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
               shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
            ),
            // Disable button while loading, otherwise call handler
            onPressed: _isLoading ? null : () => _handleBulkAdd(context), 
          );
  }
} 


        /* Expected JSON format for each question object in the list:
         {
           "moduleName": "string",
           "questionType": "string (e.g., 'multiple_choice', 'text_entry')",
           "questionElements": [
             {"type": "text", "content": "string"},
             {"type": "image", "content": "relative/path/to/image.png"} 
             // ... more elements
           ],
           "answerElements": [
             {"type": "text", "content": "string"}
             // ... more elements
           ],
           "options": ["string", "string"], // Optional: Only for 'multiple_choice'
           "correctOptionIndex": 0 // Optional: Only for 'multiple_choice' (0-indexed)
         }
        */