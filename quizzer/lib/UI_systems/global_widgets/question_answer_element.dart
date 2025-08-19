import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:path/path.dart' as p;
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_blank.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_latext_renderer.dart';


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
  final bool enabled; // Whether blank inputs should be enabled
  final List<bool> blankIsMathExpression;

  const ElementRenderer({
    super.key, 
    required this.elements,
    this.blankControllers,
    this.individualBlankResults,
    this.enabled = true, // Default to enabled
    this.blankIsMathExpression = const [],
  });



  @override
  State<ElementRenderer> createState() => _ElementRendererState();
}

class _ElementRendererState extends State<ElementRenderer> {
  
  // Store the final rendered widgets (or null if loading)
  late List<Widget?> _renderedWidgets;
  
  // Static cache for loaded images to prevent rebuilding
  static final Map<String, Widget> _imageCache = {};

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
        // Pre-load images immediately and cache them
        _preloadAndCacheImage(content, i);
      } else {
         // Handle other potential synchronous types here if needed
         _renderedWidgets[i] = _buildStaticWidget(type, content, i);
      }
    }
    // Since all widgets are now static (including images), no need for post-frame callback
  }

// Groups elements according to the specified rules
List<Widget> _groupElements() {
  List<Widget> groupedWidgets = [];
  int i = 0;

  while (i < widget.elements.length) {
    final currentElement = widget.elements[i];
    // Corrected: Use 'var' to allow reassignment inside the loop
    var currentType = currentElement['type'] as String?;

    // Start a new group if the current element is text or a blank
    if (currentType == 'text' || currentType == 'blank') {
      List<InlineSpan> inlineSpans = [];

      // Add the current element to the spans list first
      final currentWidget = _renderedWidgets[i];
      if (currentWidget != null) {
        if (currentType == 'text') {
          final textContent = currentElement['content'].toString();
          if (_hasLatexDelimiters(textContent)) {
            inlineSpans.add(WidgetSpan(
              child: LaTexT(laTeXCode: Text(textContent), equationStyle: const TextStyle(fontSize: 24.0)),
              alignment: PlaceholderAlignment.middle,
            ));
          } else {
            inlineSpans.add(TextSpan(text: textContent));
          }
        } else if (currentType == 'blank') {
          inlineSpans.add(WidgetSpan(
            child: currentWidget,
            alignment: PlaceholderAlignment.middle,
          ));
        }
      }
      i++;

      // Check if the next element is a text or blank and should be grouped
      while (i < widget.elements.length) {
        final nextElement = widget.elements[i];
        final nextType = nextElement['type'] as String?;
        final nextWidget = _renderedWidgets[i];

        // This is the critical change: Only group text with a blank or a blank with a text.
        // Do NOT group consecutive text elements.
        if (nextWidget != null && ((currentType == 'text' && nextType == 'blank') || (currentType == 'blank' && nextType == 'text'))) {
          if (nextType == 'text') {
            inlineSpans.add(const TextSpan(text: ' ')); // Add space before text
            final textContent = nextElement['content'].toString();
            if (_hasLatexDelimiters(textContent)) {
              inlineSpans.add(WidgetSpan(
                child: LaTexT(laTeXCode: Text(textContent), equationStyle: const TextStyle(fontSize: 24.0)),
                alignment: PlaceholderAlignment.middle,
              ));
            } else {
              inlineSpans.add(TextSpan(text: textContent));
            }
          } else if (nextType == 'blank') {
            inlineSpans.add(const TextSpan(text: ' ')); // Add space before blank
            inlineSpans.add(WidgetSpan(
              child: nextWidget,
              alignment: PlaceholderAlignment.middle,
            ));
            inlineSpans.add(const TextSpan(text: ' ')); // Add space after blank
          }
          i++; // Move to the next element
          currentType = nextType; // Update type for the next check
        } else {
          // Break the inner loop if the next element is not groupable with the current one.
          break;
        }
      }

      // Add the final grouped line as a single RichText widget
      if (inlineSpans.isNotEmpty) {
        groupedWidgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: inlineSpans,
            ),
          ),
        ));
      }
    } else {
      // If it's a non-groupable element (like an image), add it directly.
      final widgetToAdd = _renderedWidgets[i];
      if (widgetToAdd != null) {
        groupedWidgets.add(widgetToAdd);
      } else {
        groupedWidgets.add(const Text('[Loading...]'));
      }
      i++;
    }
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

  // Helper method that reuses the exact LaTeX detection logic from LaTexT widget
  bool _hasLatexDelimiters(String text) {
    const String delimiter = r'$';
    const String displayDelimiter = r'$$';
    
    final String escapedDelimiter = delimiter.replaceAll(r'$', r'\$');
    final String escapedDisplayDelimiter = displayDelimiter.replaceAll(r'$', r'\$');

    final String rawRegExp =
        '(($escapedDelimiter)([^$escapedDelimiter]*[^\\\\\\$escapedDelimiter])($escapedDelimiter)|($escapedDisplayDelimiter)([^$escapedDisplayDelimiter]*[^\\\\\\$escapedDisplayDelimiter])($escapedDisplayDelimiter))';
    
    final matches = RegExp(rawRegExp, dotAll: true).allMatches(text).toList();
    return matches.isNotEmpty;
  }

  // Builds widgets that DO NOT require async loading (e.g., Text, unsupported types)
  Widget _buildStaticWidget(String? type, dynamic content, int index) {
     if (content == null) {
       QuizzerLogger.logError('ElementRenderer static build encountered null content for type: $type');
       return _buildErrorIconRow('Missing content', isWarning: true);
     }
     switch (type) {
       case 'text': 
         // REMINDER: Only override text color for TextField backgrounds, not regular text display
         // Use default text color for normal text rendering
         final textContent = content.toString();
         // Use the same LaTeX detection logic as LaTexT widget
         if (_hasLatexDelimiters(textContent)) {
           return LaTexT(
             laTeXCode: Text(textContent),
             equationStyle: const TextStyle(
               fontSize: 24.0, // Increase font size for LaTeX equations
             ),
           );
         } else {
           // Use regular Text widget for plain text to handle newlines properly
           return Text(textContent);
         }
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

         // Find the correct blank index to get the isMathExpression value
         int blankIndex = 0;
         for (int i = 0; i < index; i++) {
           if (widget.elements[i]['type'] == 'blank') {
             blankIndex++;
           }
         }
         
         // Get correctness for this blank
         bool? isCorrect;
         if (widget.individualBlankResults != null && blankIndex < widget.individualBlankResults!.length) {
           isCorrect = widget.individualBlankResults![blankIndex];
         }
         
         // Get the math expression flag for this blank
         bool isMathExpression = false;
         if (blankIndex < widget.blankIsMathExpression.length) {
           isMathExpression = widget.blankIsMathExpression[blankIndex];
         }

         // Wrap the WidgetBlank in a Container with a red background as requested
         return WidgetBlank(
             width: width,
             controller: widget.blankControllers?[index] ?? TextEditingController(),
             enabled: widget.enabled, // Use the enabled parameter from ElementRenderer
             isCorrect: isCorrect,
             isMathExpression: isMathExpression, // NEW: Pass the boolean down
          );
       // Add other synchronous types here
       default:
         QuizzerLogger.logWarning('ElementRenderer static build encountered unsupported type: $type');
         return Text('[Unsupported type: $type]');
     }
  }

  // Pre-loads and caches images immediately
  void _preloadAndCacheImage(dynamic content, int index) {
    if (content == null) {
      _renderedWidgets[index] = _buildErrorIconRow('Missing image path', isWarning: true);
      return;
    }
    
    final String filename = content.toString();
    
    // Check if image is already cached
    if (_imageCache.containsKey(filename)) {
      _renderedWidgets[index] = _imageCache[filename]!;
      return;
    }
    
    // Try to load the image immediately using a synchronous approach
    _loadImageImmediately(filename, index);
  }

  // Loads image immediately if possible
  void _loadImageImmediately(String filename, int index) {
    // Try common paths first
    final List<String> possiblePaths = [
      'QuizzerAppMedia/input_staging/$filename',
      'QuizzerAppMedia/question_answer_pair_assets/$filename',
      '.local/share/com.example.quizzer/QuizzerAppMedia/input_staging/$filename',
      '.local/share/com.example.quizzer/QuizzerAppMedia/question_answer_pair_assets/$filename',
    ];
    
    for (String path in possiblePaths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final widget = Image.file(file, fit: BoxFit.contain,
            errorBuilder: (c, e, s) {
              return _buildErrorIconRow('Image unavailable', isWarning: true);
            }
          );
          _imageCache[filename] = widget;
          _renderedWidgets[index] = widget;
          return;
        } catch (e) {
          // Continue to next path
        }
      }
    }
    
    // If not found, fall back to async loading
    _buildAsyncWidgetFuture('image', filename, 0).then((widget) {
      _imageCache[filename] = widget;
      if (mounted) {
        setState(() {
          _renderedWidgets[index] = widget;
        });
      }
    });
    
    // Set a placeholder initially
    _renderedWidgets[index] = const Icon(Icons.image);
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


