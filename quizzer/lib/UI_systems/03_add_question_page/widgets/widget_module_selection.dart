import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';

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

    final result = await session.getModuleData();
    
    setState(() {
      // result is Map<String, Map<String, dynamic>> where keys are module names
      _suggestions = result.keys.toList();
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
        const Text('Module'),
        AppTheme.sizedBoxMed,
        SizedBox(
          width: width,
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                decoration: const InputDecoration(
                  hintText: 'Enter module name (default: General)',
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
                    maxWidth: width,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _getFilteredSuggestions(widget.controller.text).length,
                    itemBuilder: (context, index) {
                      final suggestion = _getFilteredSuggestions(widget.controller.text)[index];
                      return ListTile(
                        title: Text(suggestion),
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
      ],
    );
  }
} 