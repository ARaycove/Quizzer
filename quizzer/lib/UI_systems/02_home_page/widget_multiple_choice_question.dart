import 'dart:io'; // Import for File access
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import SessionManager

// Placeholder for Question/Answer Element Rendering Widget
// Now implementing basic type handling
class ElementRenderer extends StatelessWidget {
  final List<Map<String, dynamic>> elements;

  const ElementRenderer({super.key, required this.elements});

  @override
  Widget build(BuildContext context) {
    // Use a Column to display elements vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align elements left
      children: elements.map((element) {
        final type = element['type'] as String?;
        final content = element['content'] as String?;

        // Add padding between elements
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0), 
          child: _buildElementWidget(type, content),
        );
      }).toList(),
    );
  }

  // Helper method to build widget based on element type
  Widget _buildElementWidget(String? type, String? content) {
    if (content == null) {
      return const Text('[Error: Missing content]', style: TextStyle(color: Colors.redAccent));
    }

    switch (type) {
      case 'text':
        return Text(
          content,
          style: const TextStyle(color: Colors.white, fontSize: 16), // Default text style
        );
      case 'image':
        try {
          // Construct the full path using the base directory
          final String basePath = 'images/question_answer_pair_assets'; 
          // TODO: Consider making basePath configurable or using Flutter asset handling
          final String fullPath = '$basePath/$content'; 
          
          QuizzerLogger.logMessage("Attempting to load image from: $fullPath"); // Log full path
          
          final file = File(fullPath); // Use the full path
          
          // Check if file exists before attempting to load
          if (file.existsSync()) {
            // Wrap Image.file in a Center widget
            return Center(
              child: Image.file(
                 file,
                 // Add error builder for loading issues
                 errorBuilder: (context, error, stackTrace) {
                    QuizzerLogger.logError("Error loading image $fullPath: $error"); // Log full path
                    return const Row(children: [ Icon(Icons.broken_image, color: Colors.orangeAccent), SizedBox(width: 8), Text('[Image unavailable]', style: TextStyle(color: Colors.orangeAccent))]);
                 },
                 // Optional: Add width/height constraints or fit properties
                 // fit: BoxFit.contain, 
              ),
            );
          } else {
             QuizzerLogger.logWarning("Image file not found: $fullPath"); // Log full path
             // Keep error display Row as is (doesn't need centering typically)
             return Row(children: [ Icon(Icons.image_not_supported, color: Colors.orangeAccent), SizedBox(width: 8), Text('[Image not found]', style: TextStyle(color: Colors.orangeAccent))]);
          }
        } catch (e) {
           QuizzerLogger.logError("Error creating File object for path based on $content: $e"); // Log original content + error
           // Keep error display Row as is
           return Row(children: [ Icon(Icons.error_outline, color: Colors.redAccent), SizedBox(width: 8), Text('[Error loading image]', style: TextStyle(color: Colors.redAccent))]);
        }
      // TODO: Add cases for other types like 'code', 'math', etc.
      default:
        return Text(
          '[Unsupported element type: ${type ?? "null"}]', 
          style: const TextStyle(color: Colors.orangeAccent),
        );
    }
  }
}

// ==========================================

class MultipleChoiceQuestionWidget extends StatefulWidget {
  final VoidCallback onNextQuestion;

  const MultipleChoiceQuestionWidget({
    super.key,
    required this.onNextQuestion,
  });

  @override
  State<MultipleChoiceQuestionWidget> createState() =>
      _MultipleChoiceQuestionWidgetState();
}

// ---

class _MultipleChoiceQuestionWidgetState
    extends State<MultipleChoiceQuestionWidget> {
  // Get SessionManager instance
  final SessionManager session = SessionManager();

  @override
  void initState() {
    super.initState();
    // No data initialization needed here, done in build
  }

  // Make method async to but do not await submitAnswer
  Future<void> _handleOptionSelected(int index) async { 
    QuizzerLogger.logMessage('Tapped option index: $index. Current session.showingAnswer: ${session.showingAnswer}');
    // Check if already answered via SessionManager state
    if (!session.showingAnswer) { 
      QuizzerLogger.logMessage('Proceeding to update selection...');
      // Update SessionManager state using public methods
      session.setMultipleChoiceSelection(index); 
      session.setAnswerDisplayed(true);
      QuizzerLogger.logMessage('Session state updated. Calling submitAnswer...');
      
      // Submit the answer immediately
      session.submitAnswer(); 
      QuizzerLogger.logMessage('submitAnswer completed. Calling setState...');
      
      // Call setState locally to redraw UI with updated SessionManager state
      // Check mounted status after async gap
      if (mounted) {
        setState(() {}); 
      }
    } else {
      QuizzerLogger.logMessage('Option tap ignored: Already answered.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Prepare Options (Parse CSV directly) --- 
    // Parse here, assuming 'options' exists and is a valid CSV string
    final List<String> parsedOptions = 
        (session.currentQuestionData!['options'] as String? ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    // Optional: Could add a check here if parsedOptions is empty, though fail-fast might be preferred
    // if (parsedOptions.isEmpty) { ... return error ... }

    // --- Render UI --- 
    const Color secondaryBg = Color(0xFF1E2A3A);
    const Color correctColor = Color(0xFF4CAF50);
    const Color incorrectColor = Color(0xFFD64747);
    const Color defaultOptionColor = secondaryBg;
    const Color selectedOptionColor = Colors.cyan;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Question Elements ---
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: secondaryBg,
                borderRadius: BorderRadius.circular(12.0),
              ),
              // Access directly and cast
              child: ElementRenderer(elements: session.currentQuestionData!['question_elements'] as List<Map<String, dynamic>>), 
            ),
            const SizedBox(height: 20),

            // --- Options ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: parsedOptions.length, // Use parsed list
              itemBuilder: (context, index) {
                 // Access state directly from session
                final bool isSelected = session.optionSelected == index;
                 // Access correct index directly and cast
                final bool isCorrect = index == (session.currentQuestionData!['correct_option_index'] as int);
                final bool showFeedback = session.showingAnswer;

                Color? optionBgColor = defaultOptionColor;
                IconData? trailingIcon;

                // Feedback logic
                if (showFeedback) {
                  if (isSelected && isCorrect) {
                    optionBgColor = correctColor.withOpacity(0.3);
                    trailingIcon = Icons.check_circle;
                  } else if (isSelected && !isCorrect) {
                    optionBgColor = incorrectColor.withOpacity(0.3);
                    trailingIcon = Icons.cancel;
                  } else if (isCorrect) {
                    optionBgColor = correctColor.withOpacity(0.1);
                    trailingIcon = Icons.check_circle_outline;
                  }
                } else if (isSelected) {
                  optionBgColor = selectedOptionColor.withOpacity(0.2);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: InkWell(
                    onTap: () => _handleOptionSelected(index),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: optionBgColor,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isSelected ? selectedOptionColor : Colors.transparent,
                          width: 1.5
                        )
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: showFeedback ? (isCorrect ? correctColor : (isSelected ? incorrectColor : Colors.white54)) : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  parsedOptions[index], // Use item from parsed list
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ),
                              if (showFeedback && trailingIcon != null)
                                Icon(trailingIcon, color: isCorrect ? correctColor : (isSelected ? incorrectColor : Colors.grey)),
                            ],
                          ),
                          // --- Display Answer Elements ---
                          if (session.showingAnswer && isCorrect)
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0, left: 32.0),
                               // Access directly and cast
                              child: ElementRenderer(elements: session.currentQuestionData!['answer_elements'] as List<Map<String, dynamic>>), 
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // --- Next Question Button (Post-Answer) ---
            if (session.showingAnswer)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: correctColor,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _handleNextQuestion,
                child: const Text(
                  'Next Question',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Helper Methods ---

  // Handles actions before requesting the next question from parent
  void _handleNextQuestion() {
    widget.onNextQuestion();
  }
}
