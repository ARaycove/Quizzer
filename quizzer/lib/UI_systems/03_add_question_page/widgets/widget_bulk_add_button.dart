import 'dart:convert';
import 'dart:io'; // For File operations (non-web)
import 'package:flutter/foundation.dart' show kIsWeb; // For platform checks
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

// TODO Seperate add functions for each type (with built-in validation for each type)

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

  // ---
  // Bulk Add Logic
  // ---

  Future<void> _handleBulkAdd(BuildContext context) async {
    setState(() => _isLoading = true);
    int successCount = 0;
    int errorCount = 0;

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

    String fileContent;
    String fileName = result.files.single.name;
    QuizzerLogger.logMessage('Bulk Add: User selected file: $fileName');

    // 2. Read File Content
    if (kIsWeb) {
      // Web platform
      final bytes = result.files.single.bytes;
      assert(bytes != null, 'File bytes are null on web platform.');
      fileContent = utf8.decode(bytes!); // Assert non-null
    } else {
      // Native platform
      final path = result.files.single.path;
      assert(path != null, 'File path is null on native platform.');
      final file = File(path!); // Assert non-null
      fileContent = await file.readAsString();
    }
    QuizzerLogger.logMessage('Bulk Add: File content read successfully for $fileName.');

    // 3. Decode JSON
    dynamic decodedJson;
    // Using try-cast instead of try-catch for basic type check
    try {
      decodedJson = jsonDecode(fileContent);
    } on FormatException catch (e) {
        QuizzerLogger.logError('Bulk Add: Failed to decode JSON from $fileName. Error: ${e.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Invalid JSON format in $fileName.'), backgroundColor: ColorWheel.buttonError),
        );
        setState(() => _isLoading = false);
        return;
    }

    assert(decodedJson is List, 'Bulk Add: Expected JSON root to be a List, but got ${decodedJson.runtimeType}');
    final List<dynamic> questionList = decodedJson as List<dynamic>;
    QuizzerLogger.logMessage('Bulk Add: JSON decoded successfully. Found ${questionList.length} potential questions.');

    // 4. Iterate and Validate
    for (int i = 0; i < questionList.length; i++) {
      final item = questionList[i];
      final itemNumber = i + 1;

      if (item is! Map<String, dynamic>) {
        QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName is not a valid Map. Skipping.');
        errorCount++;
        continue; // Skip non-map items
      }

      final Map<String, dynamic> questionMap = item;

      // Basic Field Validation
      final String? moduleName = questionMap['moduleName'] as String?;
      final String? questionType = questionMap['questionType'] as String?;
      final List<dynamic>? questionElementsRaw = questionMap['questionElements'] as List?;
      final List<dynamic>? answerElementsRaw = questionMap['answerElements'] as List?;

      if (moduleName == null || moduleName.isEmpty) {
        QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName is missing or has empty "moduleName". Skipping.');
        errorCount++;
        continue;
      }
      if (questionType == null || questionType.isEmpty) {
        QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName is missing or has empty "questionType". Skipping.');
        errorCount++;
        continue;
      }
      if (questionElementsRaw == null || questionElementsRaw.isEmpty) {
        QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName is missing or has empty "questionElements". Skipping.');
        errorCount++;
        continue;
      }
      if (answerElementsRaw == null || answerElementsRaw.isEmpty) {
        QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName is missing or has empty "answerElements". Skipping.');
        errorCount++;
        continue;
      }

      // Element Validation (Basic)
      bool elementsValid = true;
      final List<Map<String, dynamic>> questionElements = [];
      for (final element in questionElementsRaw) {
        if (element is Map<String, dynamic> && element['type'] is String && element['content'] is String) {
          questionElements.add(element);
        } else {
          QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName has invalid structure in "questionElements". Skipping item.');
          elementsValid = false;
          break;
        }
      }
      if (!elementsValid) { errorCount++; continue; }

      final List<Map<String, dynamic>> answerElements = [];
      for (final element in answerElementsRaw) {
        if (element is Map<String, dynamic> && element['type'] is String && element['content'] is String) {
          answerElements.add(element);
        } else {
          QuizzerLogger.logError('Bulk Add: Item $itemNumber in $fileName has invalid structure in "answerElements". Skipping item.');
          elementsValid = false;
          break;
        }
      }
      if (!elementsValid) { errorCount++; continue; }

      // Multiple Choice Specific Validation
      List<Map<String, dynamic>>? options;
      int? correctOptionIndex;
      if (questionType == 'multiple_choice') {
        final List<dynamic>? optionsRaw = questionMap['options'] as List?;
        final dynamic correctIndexRaw = questionMap['correctOptionIndex'];

        if (optionsRaw == null || optionsRaw.isEmpty) {
          QuizzerLogger.logError('Bulk Add: Item $itemNumber (multiple_choice) in $fileName is missing or has empty "options". Skipping.');
          errorCount++;
          continue;
        }
        // Convert raw options to List<Map<String, dynamic>>
        options = optionsRaw.map((o) => {'type': 'text', 'content': o.toString()}).toList(); 

        if (correctIndexRaw == null) {
          QuizzerLogger.logError('Bulk Add: Item $itemNumber (multiple_choice) in $fileName is missing "correctOptionIndex". Skipping.');
          errorCount++;
          continue;
        }
        
        // Attempt to parse index safely
        if (correctIndexRaw is int) {
          correctOptionIndex = correctIndexRaw;
        } else if (correctIndexRaw is String) {
          correctOptionIndex = int.tryParse(correctIndexRaw);
        }

        if (correctOptionIndex == null || correctOptionIndex < 0 || correctOptionIndex >= options.length) {
           QuizzerLogger.logError('Bulk Add: Item $itemNumber (multiple_choice) in $fileName has invalid "correctOptionIndex": $correctIndexRaw. Index out of bounds or not an integer. Skipping.');
           errorCount++;
           continue;
        }
      }

      // 5. Add to Database (if valid)
      try {
         await _session.addNewQuestion(
           questionType: questionType,
           moduleName: moduleName,
           questionElements: questionElements,
           answerElements: answerElements,
           options: options,
           correctOptionIndex: correctOptionIndex,
         );
         successCount++;
         QuizzerLogger.logMessage('Bulk Add: Successfully added item $itemNumber from $fileName.');
      } catch (e) {
          // This catch block is ONLY for the session manager call, 
          // adhering to fail-fast for validation but handling DB errors.
          QuizzerLogger.logError('Bulk Add: Failed to add item $itemNumber from $fileName to database. Error: $e');
          errorCount++;
          // Decide whether to continue or halt on DB error. Continuing for now.
      }
    }

    // 6. Final Feedback
    QuizzerLogger.logMessage('Bulk Add: Process completed for $fileName. Success: $successCount, Errors: $errorCount');
    String feedbackMessage = 'Bulk add finished for $fileName. Added: $successCount';
    if (errorCount > 0) {
      feedbackMessage += ', Errors: $errorCount (Check logs)';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedbackMessage),
        backgroundColor: errorCount == 0 ? ColorWheel.buttonSuccess : ColorWheel.buttonError,
      ),
    );

    setState(() => _isLoading = false);
  }

  // --- 
  // Build Method
  // ---

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
            icon: _isLoading 
                  ? Container( // Replace icon with progress indicator
                      width: 18, height: 18, // Smaller size for button
                      child: const CircularProgressIndicator(
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