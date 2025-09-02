import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_module_selection.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_question_type_selection.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_bulk_add_button.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_live_preview.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/add_question_widget/widget_add_question.dart';
import 'package:quizzer/UI_systems/03_add_question_page/widgets/widget_submit_clear_buttons.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/03_add_question_page/helpers/image_picker_helper.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_quizzer_background.dart';
import 'package:quizzer/app_theme.dart';

// ==========================================

class AddQuestionAnswerPage extends StatefulWidget {
  const AddQuestionAnswerPage({super.key});

  @override
  State<AddQuestionAnswerPage> createState() => _AddQuestionAnswerPageState();
}

class _AddQuestionAnswerPageState extends State<AddQuestionAnswerPage> {
  // Instantiate SessionManager
  final SessionManager _session = SessionManager();

  // Controllers for selection widgets
  final _moduleController = TextEditingController();
  final _questionTypeController = TextEditingController();

  // --- State for the question being built ---
  // Re-introducing state based on addNewQuestion structure
  List<Map<String, dynamic>> _currentQuestionElements = [];
  List<Map<String, dynamic>> _currentAnswerElements = [];
  List<Map<String, dynamic>> _currentOptions = [];
  int?      _currentCorrectOptionIndex;       // For MC, TF
  List<int> _currentCorrectIndicesSATA = [];  // For SATA
  List<Map<String, List<String>>> _currentAnswersToBlanks = []; // For fill-in-the-blank
  // Note: _currentIsCorrectAnswerTrueTF is redundant, use _currentCorrectOptionIndex (0/1) for TF
  // --- End State Variables ---

  // --- Counter to force preview rebuild ---
  int _previewRebuildCounter = 0;

  // --- Debug Helper: Log entire question data ---
  void _logQuestionData(String operation) {
    final questionData = {
      'questionType': _questionTypeController.text,
      'moduleName': _moduleController.text,
      'questionElements': _currentQuestionElements,
      'answerElements': _currentAnswerElements,
      'options': _currentOptions,
      'correctOptionIndex': _currentCorrectOptionIndex,
      'correctIndicesSATA': _currentCorrectIndicesSATA,
      'answersToBlanks': _currentAnswersToBlanks,
    };
    
    QuizzerLogger.logMessage("=== QUESTION DATA UPDATE: $operation ===");
    QuizzerLogger.logValue("Full question data: $questionData");
    QuizzerLogger.logMessage("=== END QUESTION DATA ===");
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers and listeners
    _moduleController.text = 'general'; // Default module
    _questionTypeController.text = 'multiple_choice'; // Default question type
    _questionTypeController.addListener(_onQuestionTypeChanged);

    // Initialize state for a new, blank question
    _resetQuestionState();
  }

  @override
  void dispose() {
    _questionTypeController.removeListener(_onQuestionTypeChanged);
    _moduleController.dispose();
    _questionTypeController.dispose();
    super.dispose();
  }

  // Reset state when question type changes or for a new question
  void _resetQuestionState() {
    setState(() {
          // Start with EMPTY lists
          _currentQuestionElements = [];
          _currentAnswerElements = [];
          _currentOptions = [];
          
          // Reset type-specific answers
          final type = _questionTypeController.text;
          _currentCorrectOptionIndex = (type == 'true_false') ? 0 : null; // Default TF to True
          _currentCorrectIndicesSATA = [];
          _currentAnswersToBlanks = [];
          _previewRebuildCounter++; // Increment counter
          
          QuizzerLogger.logMessage("Resetting question state for type: $type (EMPTY)");
      });
    _logQuestionData("Reset Question State");
  }

  // Listener for question type changes
  void _onQuestionTypeChanged() {
    _resetQuestionState(); // Reset state when type changes
    // No need for setState here as _resetQuestionState calls it
  }

  // --- Placeholder Handlers (Re-added) --- 

  // Renamed param to reflect it can be type OR content
  void _handleAddElement(String typeOrContent, String category) async { // Make async
    Map<String, dynamic>? newElement; // Declare outside setState

    if (typeOrContent == 'image') {
      // Call the image picker helper
      final String? stagedImageFilename = await pickAndStageImage(); // Await the helper
      if (stagedImageFilename != null) {
        newElement = {'type': 'image', 'content': stagedImageFilename};
        QuizzerLogger.logMessage("Image element prepared with staged filename: $stagedImageFilename");
      } else {
        QuizzerLogger.logWarning("Image picking failed or was cancelled.");
        return; // Don't add anything if picking failed
      }
    } else if (typeOrContent.startsWith('blank:')) {
      // Handle blank elements with custom width: 'blank:width'
      final width = typeOrContent.substring(6); // Remove 'blank:' prefix
      newElement = {'type': 'blank', 'content': width};
    } else if (typeOrContent.isNotEmpty) {
      // Assume it's text content from the TextField
      newElement = {'type': 'text', 'content': typeOrContent};
    } else {
      QuizzerLogger.logWarning("Attempted to add empty element to $category");
      return;
    }

    // If an element was created (either text or image), add it
    setState(() { // Keep setState wrapping the list modification
      if (category == 'question') {
        _currentQuestionElements.add(newElement!);
        QuizzerLogger.logMessage("Added question element:");
        QuizzerLogger.logValue(newElement.toString());
      } else if (category == 'answer') {
        _currentAnswerElements.add(newElement!);
        QuizzerLogger.logMessage("Added answer element:");
        QuizzerLogger.logValue(newElement.toString());
      } else {
        QuizzerLogger.logError("_handleAddElement: Unknown category '$category'");
      }
      _previewRebuildCounter++; // Increment counter
    });
    _logQuestionData("Add Element");
  }
  void _handleRemoveElement(int index, String category) {
    QuizzerLogger.logMessage("Attempting to remove element index $index from $category");
    setState(() {
       List<Map<String, dynamic>> targetList;
       if (category == 'question') {
          targetList = _currentQuestionElements;
       } else if (category == 'answer') {
          targetList = _currentAnswerElements;
       } else {
          QuizzerLogger.logError("_handleRemoveElement: Unknown category '$category'");
          return;
       }

       if (index >= 0 && index < targetList.length) {
          final removedElement = targetList[index];
          targetList.removeAt(index);
          
          // If removing a blank element from question, also remove the corresponding answer
          if (category == 'question' && removedElement['type'] == 'blank') {
            // Count how many blank elements come before this one to get the correct answer index
            int blankIndex = 0;
            for (int i = 0; i < index; i++) {
              if (_currentQuestionElements[i]['type'] == 'blank') {
                blankIndex++;
              }
            }
            
            // Remove the corresponding answer from answers_to_blanks
            if (blankIndex < _currentAnswersToBlanks.length) {
              _currentAnswersToBlanks.removeAt(blankIndex);
              QuizzerLogger.logSuccess("Removed corresponding answer at index $blankIndex from answers_to_blanks");
            } else {
              QuizzerLogger.logWarning("Blank index $blankIndex out of range for answers_to_blanks (length ${_currentAnswersToBlanks.length})");
            }
          }
          
          _previewRebuildCounter++; // Increment counter
          QuizzerLogger.logSuccess("Removed element index $index from $category");
       } else {
          QuizzerLogger.logWarning("_handleRemoveElement: Invalid index $index for $category list (length ${targetList.length})");
       }
    });
    _logQuestionData("Remove Element");
  }
  void _handleEditElement(int index, String category, Map<String, dynamic> updatedElement) {
    QuizzerLogger.logMessage("Updating $category element at index $index");
    setState(() {
      List<Map<String, dynamic>> targetList;
      if (category == 'question') {
        targetList = _currentQuestionElements;
      } else if (category == 'answer') {
        targetList = _currentAnswerElements;
      } else {
        QuizzerLogger.logError("_handleEditElement: Unknown category '$category'");
        return;
      }

      if (index >= 0 && index < targetList.length) {
        targetList[index] = updatedElement;
        _previewRebuildCounter++; // Increment counter
        QuizzerLogger.logSuccess("Updated $category element at index $index.");
      } else {
        QuizzerLogger.logWarning("_handleEditElement: Invalid index $index for $category list (length ${targetList.length})");
      }
    });
    _logQuestionData("Edit Element");
  }

  void _handleAddOption(Map<String, dynamic> newOption) { // Accept the new option map
    QuizzerLogger.logMessage("Add option ${newOption['content']}");
    setState(() {
        _currentOptions.add(newOption);
        if (_currentOptions.length == 1 && _questionTypeController.text == 'multiple_choice') {
          _currentCorrectOptionIndex = 0;
        }
        _previewRebuildCounter++; // Increment counter
     });
    _logQuestionData("Add Option");
  }
  void _handleRemoveOption(int index) {
    QuizzerLogger.logMessage("Placeholder: Remove option index $index");
    setState(() {
        if (index >= 0 && index < _currentOptions.length) {
           _currentOptions.removeAt(index);
           if (_currentOptions.isEmpty) {
              _currentCorrectOptionIndex = null;
              _currentCorrectIndicesSATA = [];
           } else {
              // Add logic here to adjust MC/SATA indices if needed after removal
           }
           _previewRebuildCounter++; // Increment counter
        } else {
          QuizzerLogger.logWarning("_handleRemoveOption: Invalid index $index");
        }
    });
    _logQuestionData("Remove Option");
  }
  void _handleEditOption(int index, Map<String, dynamic> updatedOption) {
    QuizzerLogger.logMessage("Updating option at index $index");
    setState(() {
       if (index >= 0 && index < _currentOptions.length) {
          _currentOptions[index] = updatedOption;
          _previewRebuildCounter++; // Increment counter
          QuizzerLogger.logSuccess("Updated option at index $index.");
       } else {
         QuizzerLogger.logWarning("_handleEditOption: Invalid index $index for options list (length ${_currentOptions.length})");
       }
    });
    _logQuestionData("Edit Option");
  }

  void _handleSetCorrectOptionIndex(int index) {
    QuizzerLogger.logMessage("Placeholder: Set single correct index to $index");
    setState(() {
       _currentCorrectOptionIndex = index;
       // If TF, ensure index is 0 or 1
       if (_questionTypeController.text == 'true_false' && (index != 0 && index != 1)){
         _currentCorrectOptionIndex = 0; // Default back to 0 (True) if invalid
         QuizzerLogger.logWarning("Invalid index $index set for True/False. Defaulting to 0.");
       }
       _previewRebuildCounter++; // Increment counter
    });
    _logQuestionData("Set Correct Option Index");
  }
  
  void _handleToggleCorrectOptionSATA(int index) {
     QuizzerLogger.logMessage("Placeholder: Toggle SATA correct for $index");
    setState(() {
         if (_currentCorrectIndicesSATA.contains(index)) {
             _currentCorrectIndicesSATA.remove(index);
         } else {
             _currentCorrectIndicesSATA.add(index);
         }
         _currentCorrectIndicesSATA.sort();
         _previewRebuildCounter++; // Increment counter
     });
    _logQuestionData("Toggle Correct Option SATA");
  }

       // --- Handle Answers to Blanks Changes ---
    void _handleAnswersToBlanksChanged(List<Map<String, List<String>>> answersToBlanks) {
       QuizzerLogger.logMessage("Handling answers to blanks change");
       setState(() {
         _currentAnswersToBlanks = answersToBlanks;
         _previewRebuildCounter++; // Increment counter for preview update
       });
    _logQuestionData("Answers to Blanks Changed");
    }

   // --- Handle Blank Creation from Text Selection ---
   void _handleCreateBlank(int textElementIndex, String selectedText) {
     QuizzerLogger.logMessage("Creating blank from text: '$selectedText' at index $textElementIndex");
     
     if (textElementIndex < 0 || textElementIndex >= _currentQuestionElements.length) {
       QuizzerLogger.logError("Invalid text element index: $textElementIndex");
       return;
     }
     
     final originalElement = _currentQuestionElements[textElementIndex];
     if (originalElement['type'] != 'text') {
       QuizzerLogger.logError("Cannot create blank from non-text element");
       return;
     }
     
     final originalText = originalElement['content'] as String;
     final selectionStart = originalText.indexOf(selectedText);
     if (selectionStart == -1) {
       QuizzerLogger.logError("Selected text not found in original text");
       return;
     }
     
     final selectionEnd = selectionStart + selectedText.length;
     
     // Split the text into three parts
     final beforeText = originalText.substring(0, selectionStart);
     final afterText = originalText.substring(selectionEnd);
     
     QuizzerLogger.logMessage("Splitting text: before='$beforeText', selected='$selectedText', after='$afterText'");
     
     setState(() {
       // 1. Remove the original text element
       _currentQuestionElements.removeAt(textElementIndex);
       QuizzerLogger.logMessage("Removed original text element at index $textElementIndex");
       
       // 2. Add the three new elements in order
       final newElements = <Map<String, dynamic>>[];
       
       // Add before text if not empty
       if (beforeText.isNotEmpty) {
         newElements.add({'type': 'text', 'content': beforeText});
         QuizzerLogger.logMessage("Added before text element: '$beforeText'");
       }
       
       // Add the blank element with unique identifier
       final blankId = DateTime.now().millisecondsSinceEpoch.toString();
       newElements.add({'type': 'blank', 'content': selectedText.length + 2, 'blankId': blankId});
       QuizzerLogger.logMessage("Added blank element with width: ${selectedText.length + 2}, answer: '$selectedText', blankId: $blankId");
       
       // Add after text if not empty
       if (afterText.isNotEmpty) {
         newElements.add({'type': 'text', 'content': afterText});
         QuizzerLogger.logMessage("Added after text element: '$afterText'");
       }
       
       // Insert the new elements at the original position
       _currentQuestionElements.insertAll(textElementIndex, newElements);
       QuizzerLogger.logMessage("Inserted ${newElements.length} new elements at index $textElementIndex");
       
       // 3. Update answers_to_blanks to add a new answer group for this blank
       final newAnswerGroup = <String, List<String>>{};
       newAnswerGroup[selectedText] = []; // Primary answer with empty synonyms list
       _currentAnswersToBlanks.add(newAnswerGroup);
       QuizzerLogger.logMessage("Added new answer group for: '$selectedText'");
       
       _previewRebuildCounter++; // Increment counter for preview update
       
       QuizzerLogger.logSuccess("Created blank from text '$selectedText'. Added ${newElements.length} new elements and 1 answer group.");
       QuizzerLogger.logMessage("Current question elements count: ${_currentQuestionElements.length}");
     });
     _logQuestionData("Create Blank");
   }
   
   // --- Handle Answer Text Updates for Blanks ---
   void _handleUpdateAnswerText(int blankIndex, String newAnswerText) {
     QuizzerLogger.logMessage("Updating answer text for blank $blankIndex to: '$newAnswerText'");
     
     if (blankIndex < 0 || blankIndex >= _currentAnswersToBlanks.length) {
       QuizzerLogger.logError("Invalid blank index: $blankIndex");
       return;
     }
     
     setState(() {
       // Get the current answer group
       final currentAnswerGroup = _currentAnswersToBlanks[blankIndex];
       
       // Create a new answer group with the updated primary answer
       final updatedAnswerGroup = <String, List<String>>{};
       updatedAnswerGroup[newAnswerText] = currentAnswerGroup.values.first; // Keep existing synonyms
       
       // Replace the answer group
       _currentAnswersToBlanks[blankIndex] = updatedAnswerGroup;
       
       _previewRebuildCounter++; // Increment counter for preview update
       
       QuizzerLogger.logSuccess("Updated answer text for blank $blankIndex to: '$newAnswerText'");
     });
    _logQuestionData("Update Answer Text");
   }

   // --- Handle Synonyms Updates for Blanks ---
   void _handleUpdateSynonyms(int blankIndex, String primaryAnswer, List<String> synonyms) {
     QuizzerLogger.logMessage("Updating synonyms for blank $blankIndex: primary='$primaryAnswer', synonyms=$synonyms");
     
     setState(() {
       // Create a new answer group with the updated primary answer and synonyms
       final updatedAnswerGroup = <String, List<String>>{};
       updatedAnswerGroup[primaryAnswer] = synonyms;
       
       // Ensure the list is long enough
       while (_currentAnswersToBlanks.length <= blankIndex) {
         _currentAnswersToBlanks.add({});
       }
       
       // Replace the answer group
       _currentAnswersToBlanks[blankIndex] = updatedAnswerGroup;
       
       _previewRebuildCounter++; // Increment counter for preview update
       
       QuizzerLogger.logSuccess("Updated synonyms for blank $blankIndex: primary='$primaryAnswer', synonyms=$synonyms");
     });
    _logQuestionData("Update Synonyms");
   }

   void _handleReorderElements(List<Map<String, dynamic>> reorderedElements, String category) {
      QuizzerLogger.logMessage("Handling reorder for $category elements");
      setState(() {
         if (category == 'question') {
             // For question elements, we need to handle fill-in-the-blank reordering
             if (_questionTypeController.text == 'fill_in_the_blank') {
               // Find the old and new order of blank elements
               final List<String> oldBlankIds = _currentQuestionElements
                   .where((e) => e['type'] == 'blank')
                   .map((e) => e['blankId'] as String)
                   .toList();
               
               final List<String> newBlankIds = reorderedElements
                   .where((e) => e['type'] == 'blank')
                   .map((e) => e['blankId'] as String)
                   .toList();
               
               // Reorder answers_to_blanks to match the new blank order
               if (oldBlankIds.length == newBlankIds.length && 
                   oldBlankIds.length == _currentAnswersToBlanks.length) {
                 final List<Map<String, List<String>>> reorderedAnswers = [];
                 
                 for (String newBlankId in newBlankIds) {
                   final int oldIndex = oldBlankIds.indexOf(newBlankId);
                   if (oldIndex >= 0 && oldIndex < _currentAnswersToBlanks.length) {
                     reorderedAnswers.add(_currentAnswersToBlanks[oldIndex]);
                   }
                 }
                 
                 if (reorderedAnswers.length == _currentAnswersToBlanks.length) {
                   _currentAnswersToBlanks = reorderedAnswers;
                   QuizzerLogger.logMessage("Reordered answers_to_blanks to match new blank order");
                 }
               }
             }
             
             _currentQuestionElements = reorderedElements;
         } else if (category == 'answer') {
             _currentAnswerElements = reorderedElements;
         } else if (category == 'options') { // Assuming options might be reorderable later
             _currentOptions = reorderedElements;
         }
         _previewRebuildCounter++; // Increment counter
      });
    _logQuestionData("Reorder Elements");
   }

   // --- Handle Option Reordering ---
   void _handleReorderOptions(List<Map<String, dynamic>> reorderedOptions, int oldIndex, int newIndex) {
      QuizzerLogger.logMessage("Handling option reorder from $oldIndex to $newIndex");
      setState(() {
        // Update the options list
        _currentOptions = reorderedOptions;

        // --- Adjust Correct Indices --- 
        // For MC/TF: Update correct index if the correct option was moved
        if (_currentCorrectOptionIndex != null) {
          final int currentCorrectIndex = _currentCorrectOptionIndex!;
          if (currentCorrectIndex == oldIndex) {
            // The correct option was moved, update to new position
            _currentCorrectOptionIndex = newIndex;
            QuizzerLogger.logValue("MC correct index updated from $oldIndex to $newIndex after reorder.");
          } else if (currentCorrectIndex > oldIndex && currentCorrectIndex <= newIndex) {
            // An option was moved from before the correct option to after it, shift down
            _currentCorrectOptionIndex = currentCorrectIndex - 1;
            QuizzerLogger.logValue("MC correct index shifted down from $currentCorrectIndex to $_currentCorrectOptionIndex after reorder.");
          } else if (currentCorrectIndex < oldIndex && currentCorrectIndex >= newIndex) {
            // An option was moved from after the correct option to before it, shift up
            _currentCorrectOptionIndex = currentCorrectIndex + 1;
            QuizzerLogger.logValue("MC correct index shifted up from $currentCorrectIndex to $_currentCorrectOptionIndex after reorder.");
          }
        }

        // For SATA: Update all correct indices
        List<int> newCorrectIndicesSATA = [];
        for (int correctIndex in _currentCorrectIndicesSATA) {
          if (correctIndex == oldIndex) {
            // This correct option was moved, update to new position
            newCorrectIndicesSATA.add(newIndex);
          } else if (correctIndex > oldIndex && correctIndex <= newIndex) {
            // An option was moved from before this correct option to after it, shift down
            newCorrectIndicesSATA.add(correctIndex - 1);
          } else if (correctIndex < oldIndex && correctIndex >= newIndex) {
            // An option was moved from after this correct option to before it, shift up
            newCorrectIndicesSATA.add(correctIndex + 1);
          } else {
            // This correct option wasn't affected by the move
            newCorrectIndicesSATA.add(correctIndex);
          }
        }
        newCorrectIndicesSATA.sort(); // Keep sorted
        _currentCorrectIndicesSATA = newCorrectIndicesSATA;
        QuizzerLogger.logValue("SATA correct indices updated to $newCorrectIndicesSATA after reorder.");

        // --- End Adjust Correct Indices ---

        _previewRebuildCounter++; // Increment counter
      });
    _logQuestionData("Reorder Options");
   }
   // --- Validation Logic ---
   bool _validateQuestionData() {
      final String currentType = _questionTypeController.text;
      bool isValid = true; // Assume valid initially
      String errorMessage = "";

      // 1. Question Elements not empty
      if (_currentQuestionElements.isEmpty) {
         errorMessage = "Question Elements cannot be empty.";
         isValid = false;
      }
      // 2. Answer Elements not empty
      else if (_currentAnswerElements.isEmpty) {
         errorMessage = "Answer Explanation Elements cannot be empty.";
         isValid = false;
      }
      // 3. Option count for relevant types
      else if ((currentType == 'multiple_choice' || currentType == 'select_all_that_apply' || currentType == 'sort_order') && _currentOptions.length < 2) {
         errorMessage = "$currentType questions require at least 2 options.";
         isValid = false;
      }
      // 4. Correct answer selection for relevant types
      else if ((currentType == 'multiple_choice' || currentType == 'true_false') && _currentCorrectOptionIndex == null) {
         errorMessage = "A correct answer must be selected for $currentType.";
         isValid = false;
      }
      else if (currentType == 'select_all_that_apply' && _currentCorrectIndicesSATA.isEmpty) {
         errorMessage = "At least one correct answer must be selected for Select All That Apply.";
         isValid = false;
      }
      // 5. Fill-in-the-blank validation
      else if (currentType == 'fill_in_the_blank') {
         // Count blank elements in question elements
         final int blankCount = _currentQuestionElements.where((element) => element['type'] == 'blank').length;
         
         // Validate that we have answers_to_blanks data
         if (_currentAnswersToBlanks.isEmpty) {
            errorMessage = "Fill-in-the-blank questions require at least one answer group.";
            isValid = false;
         }
         // Validate that number of blank elements matches number of answer groups
         else if (blankCount != _currentAnswersToBlanks.length) {
            errorMessage = "Number of blank elements ($blankCount) does not match number of answer groups (${_currentAnswersToBlanks.length}).";
            isValid = false;
         }
         // Validate that each answer group has a primary answer
         else {
            for (int i = 0; i < _currentAnswersToBlanks.length; i++) {
               final answerGroup = _currentAnswersToBlanks[i];
               if (answerGroup.isEmpty) {
                  errorMessage = "Answer group ${i + 1} is empty. Each blank must have at least one correct answer.";
                  isValid = false;
                  break;
               }
               final primaryAnswer = answerGroup.keys.first;
               if (primaryAnswer.isEmpty) {
                  errorMessage = "Answer group ${i + 1} has an empty primary answer.";
                  isValid = false;
                  break;
               }
            }
         }
      }

      // Log and show SnackBar if invalid
      if (!isValid) {
         QuizzerLogger.logWarning("Question validation failed: $errorMessage");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Validation Failed: $errorMessage'))
            );
         }
      }
      
      return isValid;
   }

   // --- Save/Submit Logic using SessionManager ---
   void _handleSubmitQuestion() async {
      QuizzerLogger.logMessage("Attempting to submit question via SessionManager...");

      // --- 0. Validation ---
      if (!_validateQuestionData()) {
        return; // Stop if validation fails
      }

      // --- ADDED: 0.5. Finalize Staged Images ---
      try {
        // Pass the CURRENT state lists to the helper. It modifies them in place.
        await finalizeStagedImages(_currentQuestionElements, _currentAnswerElements);
      } catch (e) {
        QuizzerLogger.logError("Failed to finalize staged images during submit: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing images: $e'))
          );
        }
        return; // Stop submission if image finalization fails
      }
      // --- END ADDED ---

      // --- 1. Gather Data & Call SessionManager (Fire and Forget) ---
      QuizzerLogger.logMessage("Validation passed. Calling SessionManager.addNewQuestion (no await)... ");

      // Strip out blankId from question elements before submission (blankId is only for edit tools)
      final List<Map<String, dynamic>> cleanedQuestionElements = _currentQuestionElements.map((element) {
      if (element['type'] == 'blank') {
      final cleanedElement = Map<String, dynamic>.from(element);
      cleanedElement.remove('blankId'); // Remove blankId before submission
      return cleanedElement;
      }
      return element;
      }).toList();

      // Call without await and remove try-catch
      // Use the potentially modified element lists
      _session.addNewQuestion(
      // Required parameters
      moduleName: _moduleController.text,
      questionType: _questionTypeController.text,
      questionElements: cleanedQuestionElements, // Use cleaned list without blankId
      answerElements: _currentAnswerElements,   // Use list potentially updated by finalizeStagedImages
      // Optional / Type-specific parameters (pass null if not applicable/empty)
      answersToBlanks: _currentAnswersToBlanks,
      options: _currentOptions.isNotEmpty ? _currentOptions : null,
      correctOptionIndex: _currentCorrectOptionIndex,
      indexOptionsThatApply: _currentCorrectIndicesSATA.isNotEmpty ? _currentCorrectIndicesSATA : null,
      );
      QuizzerLogger.logMessage("$cleanedQuestionElements");

      // --- 2. Assume Success Immediately (UI Update) ---
      // No response check needed as we don't await
      QuizzerLogger.logSuccess("Question submission initiated (fire and forget). Assuming success for UI.");
      
      // --- ADDED: 2.5 Cleanup Staging Directory ---
      // Collect filenames from the submitted elements
      final Set<String> submittedImageFilenames = { 
        ..._currentQuestionElements.where((e) => e['type'] == 'image').map((e) => e['content'] as String), 
        ..._currentAnswerElements.where((e) => e['type'] == 'image').map((e) => e['content'] as String), 
      };
      // Call cleanup asynchronously (don't block UI thread)
      cleanupStagingDirectory(submittedImageFilenames).then((_) { 
          QuizzerLogger.logMessage("Async staging cleanup call finished.");
      }).catchError((error) { 
          QuizzerLogger.logError("Async staging cleanup failed: $error");
          // Log error but don't disrupt user flow
      });
      // --- END ADDED ---
     
      if (mounted) { // Still check mounted for Snack Bar
      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question Submitted!')),
          );
      }
      // Clear the form immediately
      _resetQuestionState();
      // Optionally navigate back
      // Navigator.pop(context);

      // Removed try-catch block and await
  }

  @override
  Widget build(BuildContext context) {
    final FocusNode backgroundFocusNode = FocusNode();
    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!backgroundFocusNode.hasFocus) {
          currentFocus.requestFocus(backgroundFocusNode);
        }
      },
      child: Scaffold(
        // Set the background color to transparent to allow the QuizzerBackground to show through
        // 1. Global App Bar
        appBar: const GlobalAppBar(
          title: 'Add/Edit Question',
        ),
        body: Stack(
          children: [
            Focus(
              focusNode: backgroundFocusNode,
              child: const QuizzerBackground(),
            ),
            ListView(
              children: [
                // 2. Module Selection Widget
                ModuleSelection(controller: _moduleController),
                AppTheme.sizedBoxMed,
                // 3. Question Type Selection Widget
                QuestionTypeSelection(controller: _questionTypeController),
                AppTheme.sizedBoxLrg,

                // --- Editing Controls Area --- (Moved Here)
                AddQuestionWidget(
                  questionType: _questionTypeController.text,
                  questionElements: _currentQuestionElements,
                  answerElements: _currentAnswerElements,
                  options: _currentOptions,
                  correctOptionIndex: _currentCorrectOptionIndex,
                  correctIndicesSATA: _currentCorrectIndicesSATA,
                  answersToBlanks: _currentAnswersToBlanks,
                  onAddElement: _handleAddElement,
                  onRemoveElement: _handleRemoveElement,
                  onEditElement: _handleEditElement,
                  onAddOption: _handleAddOption,
                  onRemoveOption: _handleRemoveOption,
                  onEditOption: _handleEditOption,
                  onSetCorrectOptionIndex: _handleSetCorrectOptionIndex,
                  onToggleCorrectOptionSATA: _handleToggleCorrectOptionSATA,
                  onReorderElements: _handleReorderElements,
                  onReorderOptions: _handleReorderOptions,
                  onAnswersToBlanksChanged: _handleAnswersToBlanksChanged,
                  onCreateBlank: _handleCreateBlank,
                  onUpdateAnswerText: _handleUpdateAnswerText,
                  onUpdateSynonyms: _handleUpdateSynonyms,
                ),
                AppTheme.sizedBoxLrg,

                // 4. Live Preview
                const Text("Live Preview:"),
                AppTheme.sizedBoxMed,
                LivePreviewWidget(
                  key: ValueKey('live-preview-$_previewRebuildCounter'),
                  questionType: _questionTypeController.text,
                  questionElements: _currentQuestionElements.map((element) {
                    if (element['type'] == 'blank') {
                      final cleanedElement = Map<String, dynamic>.from(element);
                      cleanedElement.remove('blankId'); // Remove blankId for preview
                      return cleanedElement;
                    }
                    return element;
                  }).toList(),
                  answerElements: _currentAnswerElements,
                  options: _currentOptions,
                  correctOptionIndexMC: _currentCorrectOptionIndex,
                  correctIndicesSATA: _currentCorrectIndicesSATA,
                  isCorrectAnswerTrueTF: (_questionTypeController.text == 'true_false')
                                          ? (_currentCorrectOptionIndex == 0)
                                          : null,
                  answersToBlanks: _currentAnswersToBlanks,
                ),
                AppTheme.sizedBoxLrg,

                // --- Submit/Clear Buttons ---
                SubmitClearButtons(
                  onSubmit: _handleSubmitQuestion,
                  onClear: _resetQuestionState, // Use existing reset logic for Clear
                ),

                AppTheme.sizedBoxLrg, // Spacing at the bottom

                // 5. Divider
                const Divider(),
                AppTheme.sizedBoxMed,

                // 6. Bulk Add Widget
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BulkAddButton(),
                  ],
                ),
                AppTheme.sizedBoxMed,
              ],
            ),
          ],
        ),
      ),
    );
  }



} 
