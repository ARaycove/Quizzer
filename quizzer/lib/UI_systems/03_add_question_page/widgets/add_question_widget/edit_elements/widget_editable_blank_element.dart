import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart'; // Added import for SessionManager

// ==========================================
//    Editable Blank Element Widget
// ==========================================
// Handles individual blank elements with inline synonym editing
//
// CRITICAL: DO NOT REVERT DOUBLE-CLICK EDITING FOR ANSWER TEXT
// ================================================================
// 
// DESIGN REQUIREMENTS:
// - Primary answer width MUST fit its content, NOT be a fixed width
// - Synonyms use Wrap to prevent overflow
// - Horizontal layout with container
// - Primary answer on left (double-click editable)
// - Synonyms in middle (double-click editable)
// - Add/remove buttons on right
// - NO SEPARATE EDIT MODE - everything inline
// - Double-click edits ANSWER TEXT, not width metadata
//
// DO NOT REVERT THIS TO WIDTH EDITING - ANSWER TEXT EDITING IS REQUIRED
// ================================================================

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
  late TextEditingController _primaryAnswerController;
  late FocusNode _primaryAnswerFocusNode;
  final List<TextEditingController> _synonymControllers = [];
  final List<FocusNode> _synonymFocusNodes = [];
  final List<bool> _isEditingSynonyms = [];
  bool _isEditingPrimary = false;
  
  // Cache for synonym suggestions to avoid duplicate API calls
  static final Map<String, List<String>> _synonymCache = {};

  @override
  void initState() {
    super.initState();
    _primaryAnswerController = TextEditingController(text: widget.answerText ?? '');
    _primaryAnswerFocusNode = FocusNode();
    _primaryAnswerFocusNode.addListener(_handlePrimaryFocusChange);
    
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
    _primaryAnswerFocusNode.removeListener(_handlePrimaryFocusChange);
    _primaryAnswerController.dispose();
    _primaryAnswerFocusNode.dispose();
    
    for (int i = 0; i < _synonymControllers.length; i++) {
      _synonymControllers[i].dispose();
      _synonymFocusNodes[i].dispose();
    }
    super.dispose();
  }

  // --- Handle Primary Answer Focus Change ---
  void _handlePrimaryFocusChange() {
    if (!_primaryAnswerFocusNode.hasFocus && _isEditingPrimary && mounted) {
      _submitPrimaryAnswer();
    }
  }

  // --- Handle Synonym Focus Change ---
  void _handleSynonymFocusChange(int index) {
    if (!_synonymFocusNodes[index].hasFocus && _isEditingSynonyms[index] && mounted) {
      _submitSynonym(index);
      setState(() {
        _isEditingSynonyms[index] = false;
      });
    }
  }

  // --- Start editing primary answer ---
  void _startEditingPrimary() {
    setState(() {
      _isEditingPrimary = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _primaryAnswerFocusNode.canRequestFocus) {
          _primaryAnswerFocusNode.requestFocus();
        }
      });
    });
  }

  // --- Submit primary answer edit ---
  void _submitPrimaryAnswer() {
    if (!mounted) return;
    
    final newAnswer = _primaryAnswerController.text;
    if (newAnswer.isEmpty) {
      QuizzerLogger.logWarning("Primary answer cannot be empty.");
      return;
    }

    // Calculate the correct blank index by counting blanks before this one
    int blankIndex = -1;
    if (widget.questionElements != null) {
      blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
    }

    // Update primary answer
    if (widget.onUpdateAnswerText != null && blankIndex >= 0) {
      widget.onUpdateAnswerText!(blankIndex, newAnswer);
    }

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
      // Remove empty synonym
      _removeSynonym(index);
      return;
    }

    // Update the controller with normalized text
    _synonymControllers[index].text = newSynonym;

    // Update synonyms
    _updateSynonyms();
  }

  // --- Add synonym ---
  void _addSynonym() {
    setState(() {
      _synonymControllers.add(TextEditingController());
      _synonymFocusNodes.add(FocusNode());
      _isEditingSynonyms.add(false);
      final newIndex = _synonymControllers.length - 1;
      _synonymFocusNodes[newIndex].addListener(() => _handleSynonymFocusChange(newIndex));
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

    // Check cache first
    if (_synonymCache.containsKey(primaryAnswer)) {
      if (mounted) {
        _showSynonymSuggestionsDialog(_synonymCache[primaryAnswer]!);
      }
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting synonym suggestions...')),
        );
      }

      // Call the SessionManager API
      final SessionManager session = SessionManager();
      final List<String> suggestions = await session.getSynonymSuggestions(primaryAnswer);

      // Cache the results
      _synonymCache[primaryAnswer] = suggestions;

      if (mounted) {
        // Show suggestions in a popup
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
    // Get current synonyms to pre-fill selections (normalized to lowercase)
    Set<String> currentSynonyms = _synonymControllers
        .map((controller) => controller.text.trim().toLowerCase())
        .where((text) => text.isNotEmpty)
        .toSet();
    
    // Track selected suggestions (pre-fill with existing synonyms)
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
                    // Add only new suggestions (not already in list)
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

    // Calculate the correct blank index by counting blanks before this one
    int blankIndex = -1;
    if (widget.questionElements != null) {
      blankIndex = widget.questionElements!.take(widget.index).where((e) => e['type'] == 'blank').length;
    }

    // Update synonyms
    if (widget.onUpdateSynonyms != null && blankIndex >= 0) {
      widget.onUpdateSynonyms!(blankIndex, primaryAnswer, synonyms);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Primary Answer (left side) - fit content, not fixed size
            GestureDetector(
              onTap: () => _startEditingPrimary(),
              child: _isEditingPrimary
                  ? IntrinsicWidth(
                      child: TextField(
                        controller: _primaryAnswerController,
                        focusNode: _primaryAnswerFocusNode,
                        autofocus: true,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Primary Answer',
                        ),
                        onSubmitted: (_) => _submitPrimaryAnswer(),
                      ),
                    )
                  : Container(
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
                    ),
            ),
            AppTheme.sizedBoxMed,
            
            // Synonyms (middle) - use Wrap to prevent overflow
            Expanded(
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
            ),
            
            // Action buttons (right side)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addSynonym,
                  tooltip: 'Add Synonym',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline), // Changed icon for synonym suggestion
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
                // Drag handle for reordering
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
