import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:math_keyboard/math_keyboard.dart';

// ==========================================
//    Editable Blank Element Widget
// ==========================================
// This widget is a single, self-contained element.
// The unfocus logic will be handled by a top-level
// GestureDetector in the parent widget.
// ==========================================
class EditableBlankElement extends StatefulWidget {
  final Map<String, dynamic> element;
  final int index;
  final String category; // 'question' or 'answer'
  final Function(int index, String category) onRemoveElement;
  final Function(int index, String category, Map<String, dynamic> updatedElement) onEditElement;
  final String? answerText; // The answer text to display in the blank
  final Function(int blankIndex, String newAnswerText)? onUpdateAnswerText; // Callback to update answers_to_blanks
  final List<Map<String, dynamic>>? questionElements; // For calculating blank index
  final List<String>? synonyms; // List of synonyms for this blank
  final Function(int blankIndex, String primaryAnswer, List<String> synonyms)? onUpdateSynonyms; // Callback to update synonyms

  const EditableBlankElement({
    super.key,
    required this.element,
    required this.index,
    required this.category,
    required this.onRemoveElement,
    required this.onEditElement,
    this.answerText,
    this.onUpdateAnswerText,
    this.questionElements,
    this.synonyms,
    this.onUpdateSynonyms,
  });

  @override
  State<EditableBlankElement> createState() => _EditableBlankElementState();
}

class _EditableBlankElementState extends State<EditableBlankElement> {
  // Use a single, central FocusNode for both the TextField and MathField.
  // This is a crucial change to properly manage focus and keyboard dismissal.
  late FocusNode _combinedFocusNode;
  
  late TextEditingController _primaryAnswerController;
  late MathFieldEditingController _mathAnswerController;
  
  final List<TextEditingController> _synonymControllers = [];
  final List<FocusNode> _synonymFocusNodes = [];
  final List<bool> _isEditingSynonyms = [];
  
  bool _isEditingPrimary = false;
  bool _isMathAnswer = false;
  
  // New state variable to hold the last valid TeX string
  late String _lastValidTex;

  // Cache for synonym suggestions to avoid duplicate API calls
  static final Map<String, List<String>> _synonymCache = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize the single combined FocusNode.
    _combinedFocusNode = FocusNode();
    _combinedFocusNode.addListener(_handlePrimaryFocusChange);
    
    _primaryAnswerController = TextEditingController(text: widget.answerText ?? '');
    
    _mathAnswerController = MathFieldEditingController();
    
    // Validate initial answerText and set _lastValidTex
    try {
      if (widget.answerText != null && widget.answerText!.startsWith(r'\')) {
        TeXParser(widget.answerText!).parse();
        _lastValidTex = widget.answerText!;
        _isMathAnswer = true;
      } else {
        _lastValidTex = '';
        _isMathAnswer = false;
      }
    } catch (e) {
      QuizzerLogger.logError('initState: Invalid initial answer text. Setting to empty.');
      _lastValidTex = '';
      _isMathAnswer = false;
    }

    // Initialize synonyms from widget
    if (widget.synonyms != null) {
      for (String synonym in widget.synonyms!) {
        _synonymControllers.add(TextEditingController(text: synonym));
        _synonymFocusNodes.add(FocusNode());
        _isEditingSynonyms.add(false);
        final index = _synonymControllers.length - 1;
        _synonymFocusNodes[index].addListener(() => _handleSynonymFocusChange(index));
      }
    }
  }

  @override
  void didUpdateWidget(covariant EditableBlankElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update primary answer if it changed
    if (oldWidget.answerText != widget.answerText) {
      // Always update the primary answer controller, regardless of type
      _primaryAnswerController.text = widget.answerText ?? '';
    }
    
    // Update synonyms if they changed
    if (oldWidget.synonyms != widget.synonyms) {
      // Clear existing synonyms
      for (var controller in _synonymControllers) {
        controller.dispose();
      }
      for (var focusNode in _synonymFocusNodes) {
        focusNode.dispose();
      }
      _synonymControllers.clear();
      _synonymFocusNodes.clear();
      _isEditingSynonyms.clear();
      
      // Add new synonyms
      if (widget.synonyms != null) {
        for (String synonym in widget.synonyms!) {
          _synonymControllers.add(TextEditingController(text: synonym));
          _synonymFocusNodes.add(FocusNode());
          _isEditingSynonyms.add(false);
          final index = _synonymControllers.length - 1;
          _synonymFocusNodes[index].addListener(() => _handleSynonymFocusChange(index));
        }
      }
    }
  }

  @override
  void dispose() {
    _combinedFocusNode.removeListener(_handlePrimaryFocusChange);
    _combinedFocusNode.dispose();
    
    _primaryAnswerController.dispose();
    _mathAnswerController.dispose();
    
    for (int i = 0; i < _synonymControllers.length; i++) {
      _synonymControllers[i].dispose();
      _synonymFocusNodes[i].dispose();
    }
    super.dispose();
  }

  // --- Handle Primary Answer Focus Change ---
  // The logic is now centralized to a single focus node.
  void _handlePrimaryFocusChange() {
    if (!mounted) return;
    if (!_combinedFocusNode.hasFocus && _isEditingPrimary) {
      _submitPrimaryAnswer();
    }
  }

  // --- Handle Synonym Focus Change ---
  void _handleSynonymFocusChange(int index) {
    if (!mounted) return;
    if (!_synonymFocusNodes[index].hasFocus && _isEditingSynonyms[index]) {
      final newSynonym = _synonymControllers[index].text.trim().toLowerCase();
      
      if (newSynonym.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _removeSynonym(index);
          }
        });
        return;
      }
      _submitSynonym(index);
      setState(() {
        _isEditingSynonyms[index] = false;
      });
    }
  }

 void _toggleIsMathAnswer() {
    setState(() {
      _isMathAnswer = !_isMathAnswer;
    });
    _updatePrimaryAnswerText(null);
    _startEditingPrimary();
  }

  // --- Update primary answer and notify parent ---
  void _updatePrimaryAnswerText(String? newAnswer) {
    int blankIndex = -1;
    if (widget.questionElements != null) {
      blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
    }
    if (widget.onUpdateAnswerText != null && blankIndex >= 0) {
      if (_isMathAnswer) {
        widget.onUpdateAnswerText!(blankIndex, _mathAnswerController.currentEditingValue());
      } else {
        widget.onUpdateAnswerText!(blankIndex, _primaryAnswerController.text);
      }
    }
  }

  // --- Start editing primary answer ---
  void _startEditingPrimary() {
    setState(() {
      _isEditingPrimary = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Request focus on the single, shared focus node.
          _combinedFocusNode.requestFocus();
        }
      });
    });
  }

  // --- Submit primary answer edit ---
  void _submitPrimaryAnswer() {
    if (!mounted) return;
    
    String newAnswer;
    if (_isMathAnswer) {
      try {
        newAnswer = _mathAnswerController.currentEditingValue();
        _lastValidTex = newAnswer;
        
        int blankIndex = -1;
        if (widget.questionElements != null) {
          blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
        }
        if (widget.onUpdateAnswerText != null && blankIndex >= 0) {
          widget.onUpdateAnswerText!(blankIndex, newAnswer);
        }
      } catch (e) {
        QuizzerLogger.logError('EditableBlankElement: Invalid math expression entered. Reverting to last valid state.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid math expression. Please correct it.'),
            backgroundColor: Colors.red,
          ),
        );
        _mathAnswerController.updateValue(TeXParser(_lastValidTex).parse());
        // Since we reverted, we should try to regain focus to allow the user to correct it.
        _combinedFocusNode.requestFocus();
        return;
      }
    } else {
      newAnswer = _primaryAnswerController.text;
      if (newAnswer.isEmpty) {
        QuizzerLogger.logWarning("Primary answer cannot be empty.");
        setState(() { _isEditingPrimary = false; });
        return;
      }
      int blankIndex = -1;
      if (widget.questionElements != null) {
        blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
      }
      if (widget.onUpdateAnswerText != null && blankIndex >= 0) {
        widget.onUpdateAnswerText!(blankIndex, newAnswer);
      }
    }
    
    // Unfocus the single combined focus node.
    _combinedFocusNode.unfocus();
    setState(() {
      _isEditingPrimary = false;
    });
  }

  // --- Start editing synonym ---
  void _startEditingSynonym(int index) {
    setState(() {
      _isEditingSynonyms[index] = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _synonymFocusNodes[index].canRequestFocus) {
          _synonymFocusNodes[index].requestFocus();
        }
      });
    });
  }

  // --- Submit synonym edit ---
  void _submitSynonym(int index) {
    if (!mounted) return;
    final newSynonym = _synonymControllers[index].text.trim().toLowerCase();
    if (newSynonym.isEmpty) {
      _removeSynonym(index);
      return;
    }
    _synonymControllers[index].text = newSynonym;
    _updateSynonyms();
  }

  // --- Add synonym ---
  void _addSynonym() {
    final newController = TextEditingController();
    final newFocusNode = FocusNode();
    final newIndex = _synonymControllers.length;
    newFocusNode.addListener(() => _handleSynonymFocusChange(newIndex));
    setState(() {
      _synonymControllers.add(newController);
      _synonymFocusNodes.add(newFocusNode);
      _isEditingSynonyms.add(true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && newIndex < _synonymFocusNodes.length && _synonymFocusNodes[newIndex].canRequestFocus) {
        _synonymFocusNodes[newIndex].requestFocus();
      }
    });
  }

  // --- Get synonym suggestions ---
  Future<void> _getSynonymSuggestions() async {
    final primaryAnswer = _primaryAnswerController.text.trim();
    if (primaryAnswer.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a primary answer first')),
        );
      }
      return;
    }
    if (_synonymCache.containsKey(primaryAnswer)) {
      if (mounted) {
        _showSynonymSuggestionsDialog(_synonymCache[primaryAnswer]!);
      }
      return;
    }
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting synonym suggestions...')),
        );
      }
      final SessionManager session = SessionManager();
      final List<String> suggestions = await session.getSynonymSuggestions(primaryAnswer);
      _synonymCache[primaryAnswer] = suggestions;
      if (mounted) {
        _showSynonymSuggestionsDialog(suggestions);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting suggestions: $e')),
        );
      }
    }
  }

  // --- Show synonym suggestions dialog ---
  void _showSynonymSuggestionsDialog(List<String> suggestions) {
    Set<String> currentSynonyms = _synonymControllers
        .map((controller) => controller.text.trim().toLowerCase())
        .where((text) => text.isNotEmpty)
        .toSet();
    Set<String> selectedSuggestions = Set<String>.from(currentSynonyms);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Synonym Suggestions for "${_primaryAnswerController.text}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    final isSelected = selectedSuggestions.contains(suggestion);
                    final isAlreadyInList = currentSynonyms.contains(suggestion);
                    return ListTile(
                      title: Text(suggestion),
                      subtitle: isAlreadyInList ? const Text('Already in list', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)) : null,
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        setDialogState(() {
                          if (isSelected) {
                            selectedSuggestions.remove(suggestion);
                          } else {
                            selectedSuggestions.add(suggestion);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    for (String suggestion in selectedSuggestions) {
                      if (!currentSynonyms.contains(suggestion)) {
                        _addSynonym();
                        final newIndex = _synonymControllers.length - 1;
                        _synonymControllers[newIndex].text = suggestion.toLowerCase();
                        _submitSynonym(newIndex);
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text('Add Selected (${selectedSuggestions.length - currentSynonyms.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Remove synonym ---
  void _removeSynonym(int index) {
    setState(() {
      _synonymControllers[index].dispose();
      _synonymFocusNodes[index].dispose();
      _synonymControllers.removeAt(index);
      _synonymFocusNodes.removeAt(index);
      _isEditingSynonyms.removeAt(index);
    });
    _updateSynonyms();
  }

  // --- Update synonyms in parent ---
  void _updateSynonyms() {
    final primaryAnswer = _primaryAnswerController.text;
    if (primaryAnswer.isEmpty) return;
    final synonyms = _synonymControllers
        .map((controller) => controller.text)
        .where((text) => text.isNotEmpty)
        .toList();
    int blankIndex = -1;
    if (widget.questionElements != null) {
      blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
    }
    if (widget.onUpdateSynonyms != null && blankIndex >= 0) {
      widget.onUpdateSynonyms!(blankIndex, primaryAnswer, synonyms);
    }
  }

  // --- Build the primary answer field widget ---
  Widget _buildPrimaryAnswerField() {
    if (_isMathAnswer) {
      return MathField(
          variables: const ["x", "y", "z", "a", "b", "c"],
          controller: _mathAnswerController,
          onChanged: (texString) {
            _updatePrimaryAnswerText(texString);
          },
          focusNode: _combinedFocusNode,
          autofocus: _isEditingPrimary,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'Enter a math expression'
          ),
        );
    } else {
      if (_isEditingPrimary) {
        return Expanded(
          child: TextField(
            controller: _primaryAnswerController,
            // Pass the single, combined focus node to the TextField.
            focusNode: _combinedFocusNode,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Primary Answer',
            ),
            onSubmitted: (_) => _submitPrimaryAnswer(),
            onChanged: (text) {
              _updatePrimaryAnswerText(text);
            },
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.answerText ?? '_____',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }
  }

  // --- Build the synonym box widget ---
  Widget _buildSynonymBox() {
    return Expanded(
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ...(_synonymControllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _startEditingSynonym(index),
                  child: _isEditingSynonyms[index]
                      ? SizedBox(
                          width: 100,
                          child: TextField(
                            controller: controller,
                            focusNode: _synonymFocusNodes[index],
                            autofocus: true,
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Synonym',
                            ),
                            onSubmitted: (_) => _submitSynonym(index),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            controller.text.isEmpty ? 'Synonym' : controller.text,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  onPressed: () => _removeSynonym(index),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            );
          })),
        ],
      ),
    );
  }

  // --- Build the action buttons widget ---
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.numbers),
          onPressed: _toggleIsMathAnswer,
          tooltip: "Toggle Math Answer",
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _addSynonym,
          tooltip: 'Add Synonym',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.lightbulb_outline),
          onPressed: _getSynonymSuggestions,
          tooltip: 'Get Synonym Suggestions',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => widget.onRemoveElement(widget.index, widget.category),
          tooltip: 'Remove Blank',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        ReorderableDragStartListener(
          index: widget.index,
          child: const Icon(Icons.drag_handle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _startEditingPrimary(),
                // The single focus node is managed by the GestureDetector.
                // The focus is requested here, which in turn gives focus to the
                // correct child widget (TextField or MathField).
                child: _buildPrimaryAnswerField(),
              ),
            ),
            AppTheme.sizedBoxMed,
            
            _buildSynonymBox(),
            
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}
