import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:path/path.dart' as p;
import 'package:quizzer/backend_systems/00_helper_utils/file_locations.dart';

// ==========================================
//        Element Renderer Widget
// ==========================================
// Renders a list of question/answer elements (text, image, etc.)

class ElementRenderer extends StatefulWidget {
  final List<Map<String, dynamic>> elements;

  const ElementRenderer({super.key, required this.elements});

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
      final content = element['content'] as String?;

      if (type == 'text' || type == null) { // Handle text and unknown types synchronously
         // Directly build and store the widget
         _renderedWidgets[i] = _buildStaticWidget(type, content);
      } else if (type == 'image') { 
        // For images (or other async types), initiate loading but store null initially
        // The async function will call setState later to update the list
         _renderedWidgets[i] = null; // Placeholder until loaded
        _loadAndSetWidget(i, type, content); 
      } else {
         // Handle other potential synchronous types here if needed
         _renderedWidgets[i] = _buildStaticWidget(type, content);
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
  Future<void> _loadAndSetWidget(int index, String? type, String? content) async {
    final Widget loadedWidget = await _buildAsyncWidgetFuture(type, content);
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

  @override
  Widget build(BuildContext context) {
    if (_renderedWidgets.isEmpty) {
      // If the list is empty after initialization (maybe elements were empty)
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_renderedWidgets.length, (index) { 
          final widget = _renderedWidgets[index];
          const elementPadding = EdgeInsets.symmetric(vertical: 4.0);

          if (widget != null) {
             // If widget is already rendered (Text or loaded Image/Error), display it
             return Padding(padding: elementPadding, child: widget);
          } else {
             // Otherwise, show the loading indicator
             return const Padding(
               padding: elementPadding, 
               child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ColorWheel.accent)),
             );
          }
      }),
    );
  }
}

// --- Static Helper Methods --- 

// Builds widgets that DO NOT require async loading (e.g., Text, unsupported types)
Widget _buildStaticWidget(String? type, String? content) {
   if (content == null) {
     QuizzerLogger.logError('ElementRenderer static build encountered null content for type: $type');
     return _buildErrorIconRow('Missing content', isWarning: true);
   }
   switch (type) {
     case 'text': 
       return Text(content, style: ColorWheel.defaultText.copyWith(color: ColorWheel.primaryText));
     // Add other synchronous types here
     default:
       QuizzerLogger.logWarning('ElementRenderer static build encountered unsupported type: $type');
       return Text('[Unsupported type: $type]', style: const TextStyle(color: ColorWheel.warning));
   }
}

// Builds widgets that REQUIRE async loading (e.g., Image)
// Returns a Future containing the final widget (Image or error display)
Future<Widget> _buildAsyncWidgetFuture(String? type, String? content) async { 
  if (type == 'image') {
    if (content == null) {
      QuizzerLogger.logError('ElementRenderer async build encountered null image content');
      return _buildErrorIconRow('Missing image path', isWarning: true);
    }
    try {
      final String filename = content;
      final String assetsPath = p.join(await getQuizzerMediaPath(), filename);
      
      File fileToCheck = File(assetsPath);
      if (await fileToCheck.exists()) {
        QuizzerLogger.logValue("ElementRenderer: Found image at platform-specific path: $assetsPath");
        return Image.file(File(assetsPath), fit: BoxFit.contain, 
          errorBuilder: (c, e, s) {
            QuizzerLogger.logError("ElementRenderer: Error loading image file $assetsPath: $e");
            return _buildErrorIconRow('Image unavailable', isWarning: true);
          }
        );
      }
      
      QuizzerLogger.logWarning("ElementRenderer: Image file '$filename' not found at $assetsPath");
      return _buildErrorIconRow('Image not found', isWarning: false);
    } catch (e) {
      QuizzerLogger.logError("ElementRenderer: Error accessing image '$content' (filename): $e");
      return _buildErrorIconRow('Error loading image', isWarning: true);
    }
  } else {
    QuizzerLogger.logWarning('ElementRenderer async build encountered unexpected type: $type');
    return _buildStaticWidget(type, content); // Build synchronously as fallback
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
         color: isWarning ? ColorWheel.warning : ColorWheel.secondaryText,
         size: 16, // Smaller icon size
       ),
       const SizedBox(width: 6),
       Flexible( // Allow text to wrap if needed
         child: Text(
           message, 
           style: TextStyle(
             color: isWarning ? ColorWheel.warning : ColorWheel.secondaryText, 
             fontSize: 12
           ),
           softWrap: true,
         )
       ),
     ]
   ); 
}
