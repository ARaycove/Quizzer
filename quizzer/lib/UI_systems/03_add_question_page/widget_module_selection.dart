import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

// ==========================================
// Widget
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
        const Text(
          'Module',
          style: ColorWheel.titleText,
        ),
        const SizedBox(height: ColorWheel.formFieldSpacing),
        Container(
          width: width,
          decoration: BoxDecoration(
            color: ColorWheel.secondaryBackground,
            borderRadius: ColorWheel.cardBorderRadius,
            border: Border.all(color: ColorWheel.accent.withAlpha(128)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ColorWheel.standardPaddingValue,
              vertical: 4.0,
            ),
            child: Column(
              children: [
                TextField(
                  controller: widget.controller,
                  style: ColorWheel.defaultText,
                  decoration: InputDecoration(
                    hintText: 'Enter module name (default: General)',
                    hintStyle: ColorWheel.defaultText.copyWith(color: ColorWheel.secondaryText),
                    filled: true,
                    fillColor: ColorWheel.secondaryBackground,
                    border: OutlineInputBorder(
                      borderRadius: ColorWheel.textFieldBorderRadius,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: ColorWheel.standardPaddingValue,
                      vertical: ColorWheel.standardPaddingValue,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(color: ColorWheel.primaryText),
                  )
                else if (widget.controller.text.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                      maxWidth: width - 2 * ColorWheel.standardPaddingValue,
                    ),
                    margin: const EdgeInsets.only(top: ColorWheel.formFieldSpacing),
                    decoration: BoxDecoration(
                      color: ColorWheel.secondaryBackground,
                      borderRadius: ColorWheel.textFieldBorderRadius,
                      border: Border.all(color: ColorWheel.accent.withAlpha(128)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _getFilteredSuggestions(widget.controller.text).length,
                      itemBuilder: (context, index) {
                        final suggestion = _getFilteredSuggestions(widget.controller.text)[index];
                        return ListTile(
                          title: Text(
                            suggestion,
                            style: ColorWheel.defaultText,
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