// import 'dart:io'; // Import for File access
// import 'package:flutter/material.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Import SessionManager
// import 'package:quizzer/UI_systems/color_wheel.dart';                          // Import ColorWheel
// // Conditionally import dart:io

// // Placeholder for Question/Answer Element Rendering Widget
// // Now implementing basic type handling
// class ElementRenderer extends StatelessWidget {
//   final List<Map<String, dynamic>> elements;

//   const ElementRenderer({super.key, required this.elements});

//   @override
//   Widget build(BuildContext context) {
//     // Use a Column to display elements vertically
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start, // Align elements left
//       children: elements.map((element) {
//         final type = element['type'] as String?;
//         final content = element['content'] as String?;

//         // Add padding between elements
//         return Padding(
//           padding: const EdgeInsets.symmetric(vertical: 4.0), 
//           child: _buildElementWidget(type, content),
//         );
//       }).toList(),
//     );
//   }

//   // Helper method to build widget based on element type
//   Widget _buildElementWidget(String? type, String? content) {
//     if (content == null) {
//       return const Text('[Error: Missing content]', style: TextStyle(color: ColorWheel.buttonError)); // Use ColorWheel
//     }

//     switch (type) {
//       case 'text':
//         return Text(
//           content,
//           style: ColorWheel.defaultText, // Use ColorWheel
//         );
//       case 'image':
//         try {
//           // Construct the full path using the base directory
//           const String basePath = 'images/question_answer_pair_assets'; 
//           final String fullPath = '$basePath/$content'; 
//           QuizzerLogger.logMessage("Attempting to load image from: $fullPath"); // Log full path
          
//           final file = File(fullPath); // Use the full path
          
//           // Check if file exists before attempting to load
//           if (file.existsSync()) {
//             // Wrap Image.file in a Center widget
//             return Center(
//               child: Image.file(
//                  file,
//                  // Add error builder for loading issues
//                  errorBuilder: (context, error, stackTrace) {
//                     QuizzerLogger.logError("Error loading image $fullPath: $error"); // Log full path
//                     return const Row(children: [ Icon(Icons.broken_image, color: ColorWheel.warning), SizedBox(width: ColorWheel.iconHorizontalSpacing), Text('[Image unavailable]', style: TextStyle(color: ColorWheel.warning))]); // Use ColorWheel
//                  },
//               ),
//             );
//           } else {
//              QuizzerLogger.logWarning("Image file not found: $fullPath"); // Log full path
//              // Keep error display Row as is (doesn't need centering typically)
//              return const Row(children: [ Icon(Icons.image_not_supported, color: ColorWheel.warning), SizedBox(width: ColorWheel.iconHorizontalSpacing), Text('[Image not found]', style: TextStyle(color: ColorWheel.warning))]); // Use ColorWheel
//           }
//         } catch (e) {
//            QuizzerLogger.logError("Error creating File object for path based on $content: $e"); // Log original content + error
//            // Keep error display Row as is
//            return const Row(children: [ Icon(Icons.error_outline, color: ColorWheel.buttonError), SizedBox(width: ColorWheel.iconHorizontalSpacing), Text('[Error loading image]', style: TextStyle(color: ColorWheel.buttonError))]); // Use ColorWheel
//         }
//       // TODO: Add cases for other types like 'code', 'math', etc.
//       default:
//         return Text(
//           '[Unsupported element type: ${type ?? "null"}]', 
//           style: const TextStyle(color: ColorWheel.warning), // Use ColorWheel
//         );
//     }
//   }
// }

// // ==========================================

// class MultipleChoiceQuestionWidget extends StatefulWidget {
//   final VoidCallback onNextQuestion;

//   const MultipleChoiceQuestionWidget({
//     super.key,
//     required this.onNextQuestion,
//   });

//   @override
//   State<MultipleChoiceQuestionWidget> createState() =>
//       _MultipleChoiceQuestionWidgetState();
// }

// // ---

// class _MultipleChoiceQuestionWidgetState
//     extends State<MultipleChoiceQuestionWidget> {
//   // Get SessionManager instance
//   final SessionManager session = SessionManager();

//   @override
//   void initState() {
//     super.initState();
//     // No data initialization needed here, done in build
//   }

//   // Make method async to but do not await submitAnswer
//   Future<void> _handleOptionSelected(int index) async { 
//     QuizzerLogger.logMessage('Tapped option index: $index. Current session.showingAnswer: ${session.showingAnswer}');
//     // Check if already answered via SessionManager state
//     if (!session.showingAnswer) { 
//       QuizzerLogger.logMessage('Proceeding to update selection...');
//       // Update SessionManager state using public methods
//       session.setMultipleChoiceSelection(index); 
//       session.setAnswerDisplayed(true);
//       QuizzerLogger.logMessage('Session state updated. Calling submitAnswer...');
      
//       // Submit the answer immediately
//       session.submitAnswer(); 
//       QuizzerLogger.logMessage('submitAnswer completed. Calling setState...');
      
//       // Call setState locally to redraw UI with updated SessionManager state
//       // Check mounted status after async gap
//       if (mounted) {
//         setState(() {}); 
//       }
//     } else {
//       QuizzerLogger.logMessage('Option tap ignored: Already answered.');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // --- Prepare Options (Parse CSV directly) --- 
//     // Parse here, assuming 'options' exists and is a valid CSV string
//     final List<String> parsedOptions = 
//         (session.currentQuestionData!['options'] as String? ?? '')
//             .split(',')
//             .map((s) => s.trim())
//             .where((s) => s.isNotEmpty)
//             .toList();
//     // Optional: Could add a check here if parsedOptions is empty, though fail-fast might be preferred
//     // if (parsedOptions.isEmpty) { ... return error ... }

//     // --- Render UI --- 
//     // Colors moved to ColorWheel, but keep specific logic variables
//     const Color correctColor = ColorWheel.buttonSuccess;
//     const Color incorrectColor = ColorWheel.buttonError;
//     const Color defaultOptionColor = ColorWheel.secondaryBackground;
//     const Color selectedOptionColor = ColorWheel.accent; // Using Accent color for selection highlight

//     return SingleChildScrollView(
//       child: Padding(
//         padding: ColorWheel.standardPadding, // Use ColorWheel
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // --- Question Elements ---
//             Container(
//               padding: ColorWheel.standardPadding, // Use ColorWheel
//               decoration: BoxDecoration(
//                 color: ColorWheel.secondaryBackground, // Use ColorWheel
//                 borderRadius: ColorWheel.cardBorderRadius, // Use ColorWheel
//               ),
//               // Access directly and cast
//               child: ElementRenderer(elements: session.currentQuestionData!['question_elements'] as List<Map<String, dynamic>>), 
//             ),
//             const SizedBox(height: ColorWheel.majorSectionSpacing), // Use ColorWheel

//             // --- Options ---
//             ListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: parsedOptions.length, // Use parsed list
//               itemBuilder: (context, index) {
//                  // Access state directly from session
//                 final bool isSelected = session.optionSelected == index;
//                  // Access correct index directly and cast
//                 final bool isCorrect = index == (session.currentQuestionData!['correct_option_index'] as int);
//                 final bool showFeedback = session.showingAnswer;

//                 Color optionBgColor = defaultOptionColor; // Initialize with const
//                 IconData? trailingIcon;

//                 // --- Determine Border Color --- 
//                 Color borderColor = Colors.transparent; // Default to no border
//                 if (isSelected) {
//                   if (showFeedback) {
//                     // Feedback phase: Border color matches correctness
//                     borderColor = isCorrect ? correctColor : incorrectColor;
//                   } else {
//                     // Selection phase (before feedback): Use accent color
//                     borderColor = selectedOptionColor;
//                   }
//                 }
//                 // --- End Determine Border Color ---

//                 // Feedback logic using ColorWheel colors (Background and Icon)
//                 if (showFeedback) {
//                   if (isSelected && isCorrect) {
//                     optionBgColor = correctColor.withAlpha(25); // 0.1 * 255 = 25.5, rounded to 25
//                     trailingIcon = Icons.check_circle;
//                   } else if (isSelected && !isCorrect) {
//                     optionBgColor = incorrectColor.withAlpha(25);
//                     trailingIcon = Icons.cancel;
//                   } else if (isCorrect) {
//                     // Slightly highlight the correct answer even if not selected
//                     optionBgColor = correctColor.withAlpha(25);
//                     // No border change needed for unselected correct answer
//                     trailingIcon = Icons.check_circle_outline; 
//                   }
//                 } else if (isSelected) {
//                   // Highlight background slightly when selected before feedback
//                   optionBgColor = selectedOptionColor.withAlpha(25);
//                 }

//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4.0),
//                   child: InkWell(
//                     onTap: () => _handleOptionSelected(index),
//                     borderRadius: ColorWheel.buttonBorderRadius, // Use ColorWheel
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//                       decoration: BoxDecoration(
//                         color: optionBgColor,
//                         borderRadius: ColorWheel.buttonBorderRadius, // Use ColorWheel
//                         border: Border.all(
//                           color: borderColor, // Use calculated border color
//                           width: 1.5
//                         )
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(
//                                 isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
//                                 color: showFeedback ? (isCorrect ? correctColor : (isSelected ? incorrectColor : ColorWheel.secondaryText)) : ColorWheel.primaryText, // Use ColorWheel
//                                 size: 20,
//                               ),
//                               const SizedBox(width: ColorWheel.relatedElementSpacing), // Use ColorWheel
//                               Expanded(
//                                 child: Text(
//                                   parsedOptions[index], // Use item from parsed list
//                                   style: ColorWheel.defaultText, // Use ColorWheel
//                                 ),
//                               ),
//                               if (showFeedback && trailingIcon != null)
//                                 Icon(trailingIcon, color: isCorrect ? correctColor : (isSelected ? incorrectColor : ColorWheel.secondaryText)), // Use ColorWheel
//                             ],
//                           ),
//                           // --- Display Answer Elements ---
//                           if (session.showingAnswer && isCorrect)
//                             Padding(
//                               padding: const EdgeInsets.only(top: ColorWheel.relatedElementSpacing, left: 32.0), // Use ColorWheel
//                                // Access directly and cast
//                               child: ElementRenderer(elements: session.currentQuestionData!['answer_elements'] as List<Map<String, dynamic>>), 
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: ColorWheel.majorSectionSpacing), // Use ColorWheel

//             // --- Next Question Button (Post-Answer) ---
//             if (session.showingAnswer)
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: ColorWheel.buttonSuccess, // Use ColorWheel
//                   padding: const EdgeInsets.symmetric(vertical: ColorWheel.standardPaddingValue), // Use ColorWheel
//                   shape: RoundedRectangleBorder(
//                     borderRadius: ColorWheel.buttonBorderRadius, // Use ColorWheel
//                   ),
//                 ),
//                 onPressed: _handleNextQuestion,
//                 child: const Text(
//                   'Next Question',
//                   style: ColorWheel.buttonText, // Use ColorWheel
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // --- Helper Methods ---

//   // Handles actions before requesting the next question from parent
//   void _handleNextQuestion() {
//     widget.onNextQuestion();
//   }
// }
