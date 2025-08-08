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
  SessionManager? session;
  List<String>   _suggestions = [];
  bool           _isLoading = false;
  

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      session = getSessionManager();
      await session!.initializationComplete;
      _loadModules();
    } catch (e) {
      // Handle session initialization error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadModules() async {
    if (session == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await session!.getModuleData();
      
      if (mounted) {
        setState(() {
          // result is Map<String, Map<String, dynamic>> where keys are module names
          _suggestions = result.keys.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getFilteredSuggestions(String query) {
    if (query.isEmpty || _suggestions.isEmpty) return [];
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
                  hintText: 'Enter module name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                )
              else if (widget.controller.text.isNotEmpty && _suggestions.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: width,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _getFilteredSuggestions(widget.controller.text).length,
                    itemBuilder: (context, index) {
                      final suggestions = _getFilteredSuggestions(widget.controller.text);
                      if (index >= suggestions.length) return const SizedBox.shrink();
                      final suggestion = suggestions[index];
                      return ListTile(
                        title: Text(suggestion),
                        onTap: () {
                          widget.controller.text = suggestion;
                          if (mounted) {
                            setState(() {});
                          }
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