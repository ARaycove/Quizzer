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
  // Note: _currentIsCorrectAnswerTrueTF is redundant, use _currentCorrectOptionIndex (0/1) for TF
  // --- End State Variables ---

  // --- Counter to force preview rebuild ---
  int _previewRebuildCounter = 0;

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
          _previewRebuildCounter++; // Increment counter
          
          QuizzerLogger.logMessage("Resetting question state for type: $type (EMPTY)");
      });
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
          targetList.removeAt(index);
          _previewRebuildCounter++; // Increment counter
          QuizzerLogger.logSuccess("Removed element index $index from $category");
       } else {
          QuizzerLogger.logWarning("_handleRemoveElement: Invalid index $index for $category list (length ${targetList.length})");
       }
    });
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
  }
   void _handleReorderElements(List<Map<String, dynamic>> reorderedElements, String category) {
      QuizzerLogger.logMessage("Placeholder: Reorder $category elements");
      setState(() {
         if (category == 'question') {
             _currentQuestionElements = reorderedElements;
         } else if (category == 'answer') {
             _currentAnswerElements = reorderedElements;
         } else if (category == 'options') { // Assuming options might be reorderable later
             _currentOptions = reorderedElements;
         }
         _previewRebuildCounter++; // Increment counter
      });
   }

   // --- Handle Option Reordering ---
   void _handleReorderOptions(List<Map<String, dynamic>> reorderedOptions) {
      QuizzerLogger.logMessage("Handling option reorder");
      setState(() {
        // Find the original indices before updating the list
        final int? oldCorrectIndexMC = _currentCorrectOptionIndex;
        final List<int> oldCorrectIndicesSATA = List.from(_currentCorrectIndicesSATA);
        final List<Map<String, dynamic>> oldOptions = List.from(_currentOptions);

        // Update the options list
        _currentOptions = reorderedOptions;

        // --- Adjust Correct Indices --- 
        // If the item(s) marked as correct have moved, update their indices.
        
        // For MC/TF: Find where the previously correct item moved to.
        if (oldCorrectIndexMC != null && oldCorrectIndexMC >= 0 && oldCorrectIndexMC < oldOptions.length) {
          final Map<String, dynamic> previouslyCorrectItem = oldOptions[oldCorrectIndexMC];
          // Find its new index in the reordered list
          final int newCorrectIndexMC = _currentOptions.indexWhere(
            (option) => option == previouslyCorrectItem // Simple identity check might suffice if objects are same
                      // Or compare content if necessary:
                      // option['type'] == previouslyCorrectItem['type'] && option['content'] == previouslyCorrectItem['content']
          );
          if (newCorrectIndexMC != -1) {
            _currentCorrectOptionIndex = newCorrectIndexMC;
             QuizzerLogger.logValue("MC correct index updated from $oldCorrectIndexMC to $newCorrectIndexMC after reorder.");
          } else {
             QuizzerLogger.logWarning("Could not find previously correct MC option after reorder. Index reset.");
             _currentCorrectOptionIndex = null; // Or default? Handle error case.
          }
        }

        // For SATA: Find the new indices for all previously correct items.
        if (oldCorrectIndicesSATA.isNotEmpty) {
          List<int> newCorrectIndicesSATA = [];
          for (int oldIndex in oldCorrectIndicesSATA) {
             if (oldIndex >= 0 && oldIndex < oldOptions.length) {
               final Map<String, dynamic> previouslyCorrectItem = oldOptions[oldIndex];
               final int newIndex = _currentOptions.indexWhere((option) => option == previouslyCorrectItem);
               if (newIndex != -1) {
                 newCorrectIndicesSATA.add(newIndex);
               }
             }
          }
          newCorrectIndicesSATA.sort(); // Keep sorted
          _currentCorrectIndicesSATA = newCorrectIndicesSATA;
          QuizzerLogger.logValue("SATA correct indices updated from $oldCorrectIndicesSATA to $newCorrectIndicesSATA after reorder.");
        }

        // --- End Adjust Correct Indices ---

        _previewRebuildCounter++; // Increment counter
      });
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

     // Call without await and remove try-catch
     // Use the potentially modified element lists
     _session.addNewQuestion(
       // Required parameters
       moduleName: _moduleController.text,
       questionType: _questionTypeController.text,
       questionElements: _currentQuestionElements, // Use list potentially updated by finalizeStagedImages
       answerElements: _currentAnswerElements,   // Use list potentially updated by finalizeStagedImages
       // Optional / Type-specific parameters (pass null if not applicable/empty)
       options: _currentOptions.isNotEmpty ? _currentOptions : null,
       correctOptionIndex: _currentCorrectOptionIndex,
       indexOptionsThatApply: _currentCorrectIndicesSATA.isNotEmpty ? _currentCorrectIndicesSATA : null,
       // Optional Metadata (pass null if not collected/available)
       citation: null,
       concepts: null,
       subjects: null,
     );

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
    return Scaffold(
      // 1. Global App Bar
      appBar: const GlobalAppBar(
        title: 'Add/Edit Question',
      ),
      body: ListView(
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
          ),
          AppTheme.sizedBoxLrg,

          // 4. Live Preview
          const Text("Live Preview:"),
          AppTheme.sizedBoxMed,
          LivePreviewWidget(
            key: ValueKey('live-preview-$_previewRebuildCounter'),
            questionType: _questionTypeController.text,
            questionElements: _currentQuestionElements,
            answerElements: _currentAnswerElements,
            options: _currentOptions,
            correctOptionIndexMC: _currentCorrectOptionIndex,
            correctIndicesSATA: _currentCorrectIndicesSATA,
            isCorrectAnswerTrueTF: (_questionTypeController.text == 'true_false')
                                    ? (_currentCorrectOptionIndex == 0)
                                    : null,
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

          // --- Editing Controls Area (Removed from here) ---
          
          // --- Live Preview Area (Removed from here) ---
        ],
      ),
    );
  }
} 
