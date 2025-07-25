import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import SessionManager
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart'; // For logging
import 'package:quizzer/UI_systems/global_widgets/widget_edit_question_dialogue.dart'; // <-- CORRECTED PACKAGE IMPORT
import 'package:quizzer/UI_systems/02_home_page/widget_question_flagging_dialogue.dart'; // Import the new flagging dialog
import 'package:quizzer/app_theme.dart';

// Convert to StatefulWidget to manage internal state for the flag dialog
class HomePageTopBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  final Future<void> Function(Map<String, dynamic> updatedQuestionData) onQuestionEdited;
  final Function(Map<String, dynamic> flagResult)? onQuestionFlagged; // Callback when question is flagged

  const HomePageTopBar({
    super.key,
    required this.onMenuPressed,
    required this.onQuestionEdited,
    this.onQuestionFlagged,
  });

  @override
  State<HomePageTopBar> createState() => _HomePageTopBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomePageTopBarState extends State<HomePageTopBar> {
  final SessionManager _session = SessionManager(); // Get session instance





  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Open Menu',
        onPressed: widget.onMenuPressed, // Access callback via widget
      ),
      title: const Text('Quizzer'),
      centerTitle: true,
      actions: [
        // --- EDIT BUTTON ---
        InkWell( // Use InkWell for tap effect, though onPressed is on IconButton
          onTap: () async {
            // Get current question ID
            final String currentQuestionId = _session.currentQuestionId;
            if (currentQuestionId.isEmpty || currentQuestionId == "dummy_no_questions") {
               QuizzerLogger.logWarning("Edit button pressed but no valid question is active.");
               // Optionally show a message to the user
               if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('No active question to edit.')),
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
                       SnackBar(content: Text('Error opening edit dialog: $e')),
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
                ),
                AppTheme.sizedBoxSml,
                Text(
                  'Edit',
                ),
              ],
            ),
          ),
        ),
        // --- FLAG BUTTON ---
        InkWell(
          onTap: () {
            // Get current question ID
            final String currentQuestionId = _session.currentQuestionId;
            if (currentQuestionId.isEmpty || currentQuestionId == "dummy_no_questions") {
              QuizzerLogger.logWarning("Flag button pressed but no valid question is active.");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No active question to flag.'),
                  ),
                );
              }
              return;
            }

            QuizzerLogger.logMessage('Flag button pressed for question ID: $currentQuestionId');
            
            // Show the flag dialog
            showDialog(
              context: context,
              builder: (dialogContext) => QuestionFlaggingDialog(
                questionId: currentQuestionId,
                onQuestionFlagged: widget.onQuestionFlagged,
              ),
            );
          },
          child: const Tooltip(
            message: 'Flag Question',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined),
                AppTheme.sizedBoxSml,
                Text(
                  'Report',
                ),
              ],
            ),
          ),
        ),
      ],

    );
  }


} 