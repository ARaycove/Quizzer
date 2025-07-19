import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import SessionManager
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // For logging
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart'; // <-- CORRECTED PACKAGE IMPORT

// Convert to StatefulWidget to manage internal state for the flag dialog
class HomePageTopBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  final Future<void> Function(Map<String, dynamic> updatedQuestionData) onQuestionEdited;

  const HomePageTopBar({
    super.key,
    required this.onMenuPressed,
    required this.onQuestionEdited,
  });

  @override
  State<HomePageTopBar> createState() => _HomePageTopBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomePageTopBarState extends State<HomePageTopBar> {
  final TextEditingController _flagController = TextEditingController();
  final SessionManager _session = SessionManager(); // Get session instance
  String _selectedFlagType = 'other'; // Default flag type

  @override
  void dispose() {
    _flagController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitFlag(BuildContext context, String reason) async {
    // Basic validation: do nothing if reason is empty
    if (reason.trim().isEmpty) {
      QuizzerLogger.logWarning('Attempted to submit flag with empty reason.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for flagging.'),
          backgroundColor: ColorWheel.warning,
        ),
      );
      return; 
    }
    
    final String currentQuestionId = _session.currentQuestionId;
    if (currentQuestionId.isEmpty || currentQuestionId == "dummy_no_questions") {
      QuizzerLogger.logWarning('Attempted to flag question but no valid question is active.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active question to flag.'),
          backgroundColor: ColorWheel.warning,
        ),
      );
      return;
    }
    
    QuizzerLogger.logMessage('Submitting flag for question: $currentQuestionId, Reason: $reason');

    try {
      // Call the addQuestionFlag API
      final bool success = await _session.addQuestionFlag(
        questionId: currentQuestionId,
        flagType: _selectedFlagType,
        flagDescription: reason.trim(),
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question flagged successfully.'),
            backgroundColor: ColorWheel.buttonSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to flag question. Please try again.'),
            backgroundColor: ColorWheel.buttonError,
          ),
        );
      }
    } catch (e) {
      QuizzerLogger.logError('Error flagging question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error flagging question: $e'),
          backgroundColor: ColorWheel.buttonError,
        ),
      );
    }

    // Clear the controller and close the dialog
    _flagController.clear();
    Navigator.pop(context); 
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ColorWheel.secondaryBackground, // Use theme color
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: ColorWheel.primaryText),
        tooltip: 'Open Menu',
        onPressed: widget.onMenuPressed, // Access callback via widget
      ),
      title: const Text('Quizzer', style: TextStyle(color: ColorWheel.primaryText)),
      centerTitle: true,
      actions: [
        // --- EDIT BUTTON ---
        Padding( // Add padding for spacing from the flag button
          padding: const EdgeInsets.only(right: 8.0), // Adjust spacing as needed
          child: InkWell( // Use InkWell for tap effect, though onPressed is on IconButton
            onTap: () async {
              // Get current question ID
              final String currentQuestionId = _session.currentQuestionId;
              if (currentQuestionId.isEmpty || currentQuestionId == "dummy_no_questions") {
                 QuizzerLogger.logWarning("Edit button pressed but no valid question is active.");
                 // Optionally show a message to the user
                 if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('No active question to edit.'), backgroundColor: ColorWheel.warning),
                     );
                 }
                 return;
              }

               QuizzerLogger.logMessage('Edit button pressed for question ID: $currentQuestionId');
               
               // Show the edit dialog and wait for result
               try {
                 if (!context.mounted) return;
                 final result = await showDialog(
                    context: context,
                    builder: (dialogContext) => EditQuestionDialog(questionId: currentQuestionId),
                 );

                 // If dialog submitted and returned data, call the callback
                 if (result != null && result is Map<String, dynamic>) {
                     await widget.onQuestionEdited(result); // Call the callback passed from HomePage
                 }
               } catch (e) {
                  QuizzerLogger.logError("Error showing edit dialog: $e");
                  if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Error opening edit dialog: $e'), backgroundColor: ColorWheel.buttonError),
                       );
                  }
               }
            },
            child: const Tooltip(
              message: 'Edit Question',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                children: [
                  Icon(
                    Icons.edit_note, // Or Icons.edit
                    color: ColorWheel.primaryText,
                    size: 24, // Standard icon size
                  ),
                  SizedBox(height: 2), // Small space between icon and text
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: ColorWheel.primaryText,
                      fontSize: 10, // Small font size
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // --- FLAG BUTTON ---
        InkWell(
          onTap: () {
            // Show flag dialog using the helper method
            showDialog(
              context: context,
              builder: (dialogContext) => _buildFlagDialog(dialogContext),
            );
          },
          child: const Tooltip(
            message: 'Flag Question',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0), // Add some horizontal padding if needed
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, color: ColorWheel.primaryText, size: 24),
                  SizedBox(height: 2), // Small space between icon and text
                  Text(
                    'Report',
                    style: TextStyle(
                      color: ColorWheel.primaryText,
                      fontSize: 10, // Small font size
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper to build the flag dialog (remains largely the same structurally)
  Widget _buildFlagDialog(BuildContext dialogContext) { // Pass context specifically for the dialog
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.8,
          padding: const EdgeInsets.all(ColorWheel.majorSectionSpacing),
          decoration: BoxDecoration(
            color: ColorWheel.secondaryBackground, // Dialog background
            borderRadius: ColorWheel.cardBorderRadius,
            border: Border.all(
              color: ColorWheel.accent, // Use accent for border
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Flag Question",
                textAlign: TextAlign.center,
                style: ColorWheel.titleText, // Use title style
              ),
              const SizedBox(height: ColorWheel.standardPaddingValue),
              // Flag Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedFlagType,
                decoration: InputDecoration(
                  labelText: "Flag Type",
                  labelStyle: ColorWheel.hintTextStyle,
                  filled: true,
                  fillColor: ColorWheel.textInputBackground,
                  border: OutlineInputBorder(
                    borderRadius: ColorWheel.textFieldBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: ColorWheel.inputFieldPadding,
                ),
                style: ColorWheel.defaultText.copyWith(color: ColorWheel.inputText),
                items: const [
                  DropdownMenuItem(value: 'factually_incorrect', child: Text('Factually Incorrect')),
                  DropdownMenuItem(value: 'misleading_information', child: Text('Misleading Information')),
                  DropdownMenuItem(value: 'outdated_content', child: Text('Outdated Content')),
                  DropdownMenuItem(value: 'confusing_question', child: Text('Confusing Question')),
                  DropdownMenuItem(value: 'incorrect_answer', child: Text('Incorrect Answer')),
                  DropdownMenuItem(value: 'grammar_spelling_errors', child: Text('Grammar/Spelling Errors')),
                  DropdownMenuItem(value: 'duplicate_question', child: Text('Duplicate Question')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFlagType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: ColorWheel.standardPaddingValue),
              TextField(
                controller: _flagController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Please explain the issue...",
                  hintStyle: ColorWheel.hintTextStyle, // Use hint style
                  filled: true,
                  fillColor: ColorWheel.textInputBackground, // Use input background color
                  border: OutlineInputBorder(
                    borderRadius: ColorWheel.textFieldBorderRadius,
                    borderSide: BorderSide.none, // Keep borderless appearance
                  ),
                  contentPadding: ColorWheel.inputFieldPadding,
                ),
                style: ColorWheel.defaultText.copyWith(color: ColorWheel.inputText), // Use correct input text color
              ),
              const SizedBox(height: ColorWheel.standardPaddingValue),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _flagController.clear(); // Clear on cancel
                      Navigator.pop(dialogContext); // Use dialog context to pop
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorWheel.buttonSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: ColorWheel.buttonBorderRadius,
                      ),
                    ),
                    child: const Text("Cancel", style: ColorWheel.buttonText),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleSubmitFlag(dialogContext, _flagController.text), // Pass context and text
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorWheel.buttonSuccess,
                      shape: RoundedRectangleBorder(
                        borderRadius: ColorWheel.buttonBorderRadius,
                      ),
                    ),
                    child: const Text("Submit Flag", style: ColorWheel.buttonTextBold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 