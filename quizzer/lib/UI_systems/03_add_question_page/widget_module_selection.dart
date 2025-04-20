import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

// Colors
const Color _surfaceColor = Color(0xFF1E2A3A); // Secondary Background
const Color _primaryColor = Color(0xFF4CAF50); // Accent Color
const Color _textColor = Colors.white; // Primary Text

// Spacing and Dimensions
const double _borderRadius = 12.0;
const double _spacing = 16.0;
const double _fieldSpacing = 8.0; // Spacing between form fields

class ModuleSelection extends StatefulWidget {
  final TextEditingController controller;

  const ModuleSelection({
    super.key,
    required this.controller,
  });

  @override
  State<ModuleSelection> createState() => _ModuleSelectionState();
}

class _ModuleSelectionState extends State<ModuleSelection> {
  SessionManager session = getSessionManager();
  List<String>   _suggestions = [];
  bool           _isLoading = false;
  

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
    });

    final result = await session.loadModules();
    
    setState(() {
      _suggestions = (result['modules'] as List<Map<String, dynamic>>)
          .map((m) => m['module_name'] as String)
          .toList();
      _isLoading = false;
    });
  }

  List<String> _getFilteredSuggestions(String query) {
    if (query.isEmpty) return [];
    return _suggestions
        .where((module) => module.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use 85% of screen width with a max of 460px to match logo width guideline
    final width = screenWidth * 0.85 > 460 ? 460.0 : screenWidth * 0.85;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Module',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: _fieldSpacing),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(color: _primaryColor.withAlpha(128)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _spacing,
              vertical: 4.0,
            ),
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  style: const TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Enter module name (default: General)',
                    hintStyle: TextStyle(color: _textColor.withAlpha(153)),
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(_borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: _spacing,
                      vertical: _spacing,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(),
                  )
                else if (widget.controller.text.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                      maxWidth: width - 2 * _spacing,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(_borderRadius),
                      border: Border.all(color: _primaryColor.withAlpha(128)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _getFilteredSuggestions(widget.controller.text).length,
                      itemBuilder: (context, index) {
                        final suggestion = _getFilteredSuggestions(widget.controller.text)[index];
                        return ListTile(
                          title: Text(
                            suggestion,
                            style: const TextStyle(color: _textColor),
                          ),
                          onTap: () {
                            widget.controller.text = suggestion;
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 