import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:path/path.dart' as p;
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_blank.dart';

// ==========================================
//        Element Renderer Widget
// ==========================================
// Renders a list of question/answer elements (text, image, etc.)
//
// CRITICAL DATA STRUCTURE DOCUMENTATION
// =====================================
//
// ELEMENT DATA STRUCTURES:
// =======================
//
// 1. TEXT ELEMENTS:
//    {'type': 'text', 'content': 'string content'}
//    - content: String containing the text to display
//    - Example: {'type': 'text', 'content': 'What is the capital of France?'}
//
// 2. IMAGE ELEMENTS:
//    {'type': 'image', 'content': 'filename.ext'}
//    - content: String containing the image filename (not full path)
//    - Images are stored in staging or media directories
//    - Example: {'type': 'image', 'content': 'france_map.png'}
//
// 3. BLANK ELEMENTS (fill-in-the-blank questions):
//    {'type': 'blank', 'content': int}
//    - content: Integer representing the width of the blank input field
//    - This is the ONLY element type that stores content as int, not String
//    - Example: {'type': 'blank', 'content': 10}
//
// ANSWERS_TO_BLANKS STRUCTURE (for fill-in-the-blank questions):
// ============================================================
//
// answers_to_blanks: List<Map<String, List<String>>>
// Each Map represents one blank element and contains:
// - Key: Primary correct answer (String)
// - Value: List of synonyms/alternative answers (List<String>)
//
// Example answers_to_blanks:
// [
//   {'Paris': ['paris', 'PARIS']},           // First blank: accepts "Paris", "paris", "PARIS"
//   {'Eiffel Tower': ['eiffel', 'tower']},   // Second blank: accepts "Eiffel Tower", "eiffel", "tower"
// ]
//
// BLANK INDEX MAPPING:
// - answers_to_blanks[0] corresponds to the first blank element in question_elements
// - answers_to_blanks[1] corresponds to the second blank element in question_elements
// - etc.
//
// QUESTION TYPES AND THEIR DATA STRUCTURES:
// ========================================
//
// 1. multiple_choice:
//    - question_elements: List<Map<String, dynamic>> (text/image elements)
//    - answer_elements: List<Map<String, dynamic>> (explanation elements)
//    - options: List<Map<String, dynamic>> (choice elements)
//    - correct_option_index: int (index of correct option)
//
// 2. select_all_that_apply:
//    - question_elements: List<Map<String, dynamic>> (text/image elements)
//    - answer_elements: List<Map<String, dynamic>> (explanation elements)
//    - options: List<Map<String, dynamic>> (choice elements)
//    - index_options_that_apply: List<int> (indices of correct options)
//
// 3. true_false:
//    - question_elements: List<Map<String, dynamic>> (text/image elements)
//    - answer_elements: List<Map<String, dynamic>> (explanation elements)
//    - options: List<Map<String, dynamic>> (auto-generated True/False)
//    - correct_option_index: int (0 for True, 1 for False)
//
// 4. sort_order:
//    - question_elements: List<Map<String, dynamic>> (text/image elements)
//    - answer_elements: List<Map<String, dynamic>> (explanation elements)
//    - options: List<Map<String, dynamic>> (items to sort)
//    - correct_order: List<int> (correct order indices)
//
// 5. fill_in_the_blank:
//    - question_elements: List<Map<String, dynamic>> (text/image/blank elements)
//    - answer_elements: List<Map<String, dynamic>> (explanation elements)
//    - answers_to_blanks: List<Map<String, List<String>>> (blank answers)
//    - NO options field (blanks are embedded in question_elements)
//
// IMPORTANT NOTES:
// ===============
// - Blank elements are ONLY used in fill_in_the_blank questions
// - Blank content is ALWAYS int (width), never String
// - Image content is ALWAYS String (filename), never int
// - Text content is ALWAYS String, never int
// - answers_to_blanks is ONLY used for fill_in_the_blank questions
// - The number of blank elements must equal the length of answers_to_blanks
//
// =====================================

class ElementRenderer extends StatefulWidget {
  final List<Map<String, dynamic>> elements;
  final Map<int, TextEditingController>? blankControllers; // Map of element index to controller
  final List<bool>? individualBlankResults; // Individual blank correctness results

  const ElementRenderer({
    super.key, 
    required this.elements,
    this.blankControllers,
    this.individualBlankResults,
  });

  @override
  State<ElementRenderer> createState() => _ElementRendererState();
}

class _ElementRendererState extends State<ElementRenderer> {
  
  // Store the final rendered widgets (or null if loading)
  late List<Widget?> _renderedWidgets;

  @override
  void initState() {
    super.initState();
    _initializeWidgets();
  }

  @override
  void didUpdateWidget(covariant ElementRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Basic check for element list change
    if (widget.elements != oldWidget.elements) { 
      // QuizzerLogger.logMessage("ElementRenderer detected elements change in didUpdateWidget.");
      _initializeWidgets(); // Re-initialize if elements change
    }
  }

  // Initializes the widget list, calling async loaders for relevant types
  void _initializeWidgets() {
    // Initialize list with nulls
    _renderedWidgets = List<Widget?>.filled(widget.elements.length, null);

    for (int i = 0; i < widget.elements.length; i++) {
      final element = widget.elements[i];
      final type = element['type'] as String?;
      final content = element['content'];

      if (type == 'text' || type == null) { // Handle text and unknown types synchronously
         // Directly build and store the widget
         _renderedWidgets[i] = _buildStaticWidget(type, content, i);
      } else if (type == 'blank') {
         // Handle blank elements synchronously (content is int)
         _renderedWidgets[i] = _buildStaticWidget(type, content, i);
      } else if (type == 'image') { 
        // For images (or other async types), initiate loading but store null initially
        // The async function will call setState later to update the list
         _renderedWidgets[i] = null; // Placeholder until loaded
        _loadAndSetWidget(i, type, content); 
      } else {
         // Handle other potential synchronous types here if needed
         _renderedWidgets[i] = _buildStaticWidget(type, content, i);
      }
    }
    // Initial synchronous widgets are set, trigger a build if state hasn't been set by async calls yet
    // Using addPostFrameCallback ensures this happens after the current build cycle if called from initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
             // We only need to trigger a rebuild if synchronous widgets were added
             // or if the list was initially empty. Async updates handle their own setState.
             // A simple check: if any widget is non-null, ensure build runs.
             if (_renderedWidgets.any((w) => w != null)) {
                 setState(() {}); 
             }
        }
    });
  }

  // Async helper to load widget and update state
  Future<void> _loadAndSetWidget(int index, String? type, dynamic content) async {
    final Widget loadedWidget = await _buildAsyncWidgetFuture(type, content, index);
    if (mounted) { // Check if the widget is still mounted before calling setState
      setState(() {
        // Ensure the list index is still valid (elements might have changed)
        if (index < _renderedWidgets.length) {
             _renderedWidgets[index] = loadedWidget;
        } else {
             QuizzerLogger.logWarning("ElementRenderer: Index out of bounds when setting async widget. Elements may have changed rapidly.");
        }
      });
    }
  }

  // Groups elements according to the specified rules
  List<Widget> _groupElements() {
    List<Widget> groupedWidgets = [];
    int i = 0;
    
    while (i < _renderedWidgets.length) {
      final currentWidget = _renderedWidgets[i];
      
      if (currentWidget == null) {
        // Show loading indicator for async widgets
        groupedWidgets.add(const CircularProgressIndicator());
        i++;
        continue;
      }
      
      // Check if current element is a blank
      final currentElement = widget.elements[i];
      final currentType = currentElement['type'] as String?;
      
      if (currentType == 'blank') {
        // Check if next element should be grouped with this blank
        if (i + 1 < _renderedWidgets.length) {
          final nextElement = widget.elements[i + 1];
          final nextType = nextElement['type'] as String?;
          
          // Group blank with text or another blank
          if (nextType == 'text' || nextType == 'blank') {
            List<Widget> rowChildren = [currentWidget];
            i++; // Move to next element
            
            // Continue adding elements to the row until we hit an image or end
            while (i < _renderedWidgets.length) {
              final nextWidget = _renderedWidgets[i];
              final nextElementType = widget.elements[i]['type'] as String?;
              
              if (nextWidget == null) {
                // If async widget is still loading, break the row
                break;
              }
              
              if (nextElementType == 'text' || nextElementType == 'blank') {
                rowChildren.add(nextWidget);
                i++;
              } else {
                // Stop at image or other types
                break;
              }
            }
            
            groupedWidgets.add(Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowChildren,
            ));
            continue;
          }
        }
      } else if (currentType == 'text') {
        // Check if next element is a blank and should be grouped with this text
        if (i + 1 < _renderedWidgets.length) {
          final nextElement = widget.elements[i + 1];
          final nextType = nextElement['type'] as String?;
          
          // Group text with blank
          if (nextType == 'blank') {
            List<Widget> rowChildren = [currentWidget];
            i++; // Move to next element
            
            // Continue adding elements to the row until we hit an image or end
            while (i < _renderedWidgets.length) {
              final nextWidget = _renderedWidgets[i];
              final nextElementType = widget.elements[i]['type'] as String?;
              
              if (nextWidget == null) {
                // If async widget is still loading, break the row
                break;
              }
              
              if (nextElementType == 'text' || nextElementType == 'blank') {
                rowChildren.add(nextWidget);
                i++;
              } else {
                // Stop at image or other types
                break;
              }
            }
            
            groupedWidgets.add(Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowChildren,
            ));
            continue;
          }
        }
      }
      
      // Single element (not grouped)
      groupedWidgets.add(currentWidget);
      i++;
    }
    
    return groupedWidgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_renderedWidgets.isEmpty) {
      // If the list is empty after initialization (maybe elements were empty)
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _groupElements(),
    );
  }

  // Builds widgets that DO NOT require async loading (e.g., Text, unsupported types)
  Widget _buildStaticWidget(String? type, dynamic content, int index) {
     if (content == null) {
       QuizzerLogger.logError('ElementRenderer static build encountered null content for type: $type');
       return _buildErrorIconRow('Missing content', isWarning: true);
     }
     switch (type) {
       case 'text': 
         return Text(content.toString());
       case 'blank':
         // Parse content as width for the blank widget
         int width;
         try {
                    // Handle integer content directly as per database format
         width = content is int ? content : int.parse(content.toString());
         } catch (e) {
           QuizzerLogger.logError('ElementRenderer: Invalid blank width content: $content');
           width = 10; // Default width
         }
         // Create a controller for the blank widget
         final controller = widget.blankControllers?[index] ?? TextEditingController();
         
         // Get correctness for this blank
         bool? isCorrect;
         if (widget.individualBlankResults != null) {
           // Count how many blanks come before this one to get the correct index
           int blankIndex = 0;
           for (int i = 0; i < index; i++) {
             if (widget.elements[i]['type'] == 'blank') {
               blankIndex++;
             }
           }
           if (blankIndex < widget.individualBlankResults!.length) {
             isCorrect = widget.individualBlankResults![blankIndex];
           }
         }
         
         return WidgetBlank(
           width: width,
           controller: controller,
           enabled: true, // Always enabled for now, we'll handle preview mode differently
           isCorrect: isCorrect,
         );
       // Add other synchronous types here
       default:
         QuizzerLogger.logWarning('ElementRenderer static build encountered unsupported type: $type');
         return Text('[Unsupported type: $type]');
     }
  }

  // Builds widgets that REQUIRE async loading (e.g., Image)
  // Returns a Future containing the final widget (Image or error display)
  Future<Widget> _buildAsyncWidgetFuture(String? type, dynamic content, int index) async { 
    if (type == 'image') {
      if (content == null) {
        QuizzerLogger.logError('ElementRenderer async build encountered null image content');
        return _buildErrorIconRow('Missing image path', isWarning: true);
      }
      try {
        final String filename = content.toString();
        
        // First check staging path (for images that haven't been submitted yet)
        final String stagingPath = p.join(await getInputStagingPath(), filename);
        File stagingFile = File(stagingPath);
        if (await stagingFile.exists()) {
          QuizzerLogger.logValue("ElementRenderer: Found image in staging: $stagingPath");
          return Image.file(stagingFile, fit: BoxFit.contain, 
            errorBuilder: (c, e, s) {
              QuizzerLogger.logError("ElementRenderer: Error loading staging image $stagingPath: $e");
              return _buildErrorIconRow('Image unavailable', isWarning: true);
            }
          );
        }
        
        // Then check media path (for submitted images)
        final String mediaPath = p.join(await getQuizzerMediaPath(), filename);
        File mediaFile = File(mediaPath);
        if (await mediaFile.exists()) {
          QuizzerLogger.logValue("ElementRenderer: Found image in media: $mediaPath");
          return Image.file(mediaFile, fit: BoxFit.contain, 
            errorBuilder: (c, e, s) {
              QuizzerLogger.logError("ElementRenderer: Error loading media image $mediaPath: $e");
              return _buildErrorIconRow('Image unavailable', isWarning: true);
            }
          );
        }
        
        QuizzerLogger.logWarning("ElementRenderer: Image file '$filename' not found in staging or media paths");
        return _buildErrorIconRow('Image not found', isWarning: false);
      } catch (e) {
        QuizzerLogger.logError("ElementRenderer: Error accessing image '$content' (filename): $e");
        return _buildErrorIconRow('Error loading image', isWarning: true);
      }
    } else {
      QuizzerLogger.logWarning('ElementRenderer async build encountered unexpected type: $type');
      return _buildStaticWidget(type, content, index); // Pass the actual index
    }
  }
}

// Builds a standard row with an icon and text for errors or info
// This can remain a static/top-level function or part of the state class if preferred.
Widget _buildErrorIconRow(String message, {required bool isWarning}) {
   return Row(
     mainAxisSize: MainAxisSize.min,
     crossAxisAlignment: CrossAxisAlignment.center,
     children: [
       Icon(
         isWarning ? Icons.warning_amber_rounded : Icons.image_not_supported,
       ),
       AppTheme.sizedBoxSml,
       Flexible( // Allow text to wrap if needed
         child: Text(
           message, 
           softWrap: true,
         )
       ),
     ]
   ); 
}
