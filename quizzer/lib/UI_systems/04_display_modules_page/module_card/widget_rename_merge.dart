import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ModuleRenameMergeWidget extends StatefulWidget {
  final String currentModuleName;
  final VoidCallback? onModuleUpdated;

  const ModuleRenameMergeWidget({
    super.key,
    required this.currentModuleName,
    this.onModuleUpdated,
  });

  @override
  State<ModuleRenameMergeWidget> createState() => _ModuleRenameMergeWidgetState();
}

class _ModuleRenameMergeWidgetState extends State<ModuleRenameMergeWidget> {
  final TextEditingController _renameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedMergeTarget;
  List<Map<String, dynamic>> _availableModules = [];
  bool _isLoading = false;
  bool _showRenameField = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableModules();
    _searchController.addListener(_filterModules);
  }

  @override
  void dispose() {
    _renameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterModules() {
    setState(() {
    });
  }

  Future<void> _loadAvailableModules() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final sessionManager = getSessionManager();
      final Map<String, Map<String, dynamic>> modulesWithQuestions = await sessionManager.getModuleData(onlyWithQuestions: true);
      final List<Map<String, dynamic>> availableModules = modulesWithQuestions.entries
          .where((entry) => entry.key != widget.currentModuleName)
          .map((entry) => {
            'module_name': entry.key,
            ...entry.value,
          })
          .toList();

      setState(() {
        _availableModules = availableModules;
        _isLoading = false;
      });
    } catch (e) {
      QuizzerLogger.logError('Error loading available modules: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _renameModule() async {
    final String newName = _renameController.text.trim();
    if (newName.isEmpty) {
      _showErrorSnackBar('Please enter a new module name');
      return;
    }
    if (newName == widget.currentModuleName) {
      _showErrorSnackBar('New name must be different from current name');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final sessionManager = getSessionManager();
      final bool success = await sessionManager.renameModule(widget.currentModuleName, newName);
      if (success) {
        _showSuccessSnackBar('Module renamed successfully');
        _renameController.clear();
        setState(() {
          _showRenameField = false;
        });
        widget.onModuleUpdated?.call();
      } else {
        _showErrorSnackBar('Failed to rename module');
      }
    } catch (e) {
      QuizzerLogger.logError('Error renaming module: $e');
      _showErrorSnackBar('Error renaming module: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _mergeModule() async {
    if (_selectedMergeTarget == null) {
      _showErrorSnackBar('Please select a target module');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final sessionManager = getSessionManager();
      final bool success = await sessionManager.mergeModules(
        widget.currentModuleName,
        _selectedMergeTarget!,
      );
      if (success) {
        _showSuccessSnackBar('Module merged successfully');
        setState(() {
          _selectedMergeTarget = null;
        });
        widget.onModuleUpdated?.call();
      } else {
        _showErrorSnackBar('Failed to merge module');
      }
    } catch (e) {
      QuizzerLogger.logError('Error merging module: $e');
      _showErrorSnackBar('Error merging module: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: ColorWheel.buttonText),
        backgroundColor: ColorWheel.buttonError,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: ColorWheel.buttonText),
        backgroundColor: ColorWheel.buttonSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Text(
          'Module Management',
          style: ColorWheel.titleText,
        ),
        const SizedBox(height: ColorWheel.majorSectionSpacing),
        // Rename Section
        Card(
          color: ColorWheel.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: ColorWheel.cardBorderRadius,
          ),
          child: Padding(
            padding: ColorWheel.standardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, color: ColorWheel.accent, size: ColorWheel.standardIconSize),
                    const SizedBox(width: ColorWheel.iconHorizontalSpacing),
                    const Text(
                      'Rename Module',
                      style: ColorWheel.titleText,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showRenameField = !_showRenameField;
                          if (!_showRenameField) {
                            _renameController.clear();
                          }
                        });
                      },
                      icon: Icon(_showRenameField ? Icons.expand_less : Icons.expand_more, color: ColorWheel.primaryText),
                    ),
                  ],
                ),
                if (_showRenameField) ...[
                  const SizedBox(height: ColorWheel.formFieldSpacing),
                  TextField(
                    controller: _renameController,
                    style: ColorWheel.defaultText,
                    cursorColor: ColorWheel.primaryText,
                    decoration: InputDecoration(
                      labelText: 'New Module Name',
                      labelStyle: const TextStyle(color: ColorWheel.primaryText),
                      hintText: 'Enter new name...',
                      hintStyle: const TextStyle(color: ColorWheel.primaryText),
                      filled: true,
                      fillColor: ColorWheel.primaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.primaryBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.primaryBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: ColorWheel.textFieldBorderRadius,
                        borderSide: const BorderSide(color: ColorWheel.accent),
                      ),
                      contentPadding: ColorWheel.inputFieldPadding,
                    ),
                  ),
                  const SizedBox(height: ColorWheel.formFieldSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _renameModule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorWheel.buttonError,
                        foregroundColor: ColorWheel.primaryText,
                        shape: RoundedRectangleBorder(
                          borderRadius: ColorWheel.buttonBorderRadius,
                        ),
                        padding: ColorWheel.buttonPadding,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ColorWheel.primaryText),
                            )
                          : const Text('Rename', style: ColorWheel.buttonTextBold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: ColorWheel.relatedElementSpacing),
        // Merge Section
        Card(
          color: ColorWheel.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: ColorWheel.cardBorderRadius,
          ),
          child: Padding(
            padding: ColorWheel.standardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.merge, color: ColorWheel.accent, size: ColorWheel.standardIconSize),
                    SizedBox(width: ColorWheel.iconHorizontalSpacing),
                    Text(
                      'Merge Module',
                      style: ColorWheel.titleText,
                    ),
                  ],
                ),
                const SizedBox(height: ColorWheel.formFieldSpacing),
                const Text(
                  'Merge this module into another module. All questions will be moved to the target module.',
                  style: ColorWheel.secondaryTextStyle,
                ),
                const SizedBox(height: ColorWheel.formFieldSpacing),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: ColorWheel.primaryText),
                  )
                else if (_availableModules.isEmpty)
                  Text(
                    'No other modules with questions available for merging',
                    style: ColorWheel.secondaryTextStyle.copyWith(fontStyle: FontStyle.italic),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: ColorWheel.primaryBorder,
                          secondary: ColorWheel.primaryBorder,
                        ),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        focusColor: Colors.transparent,
                      ),
                      child: DropdownSearch<String>(
                        items: (String filter, _) async {
                          final modules = _availableModules.map((module) => module['module_name'] as String).toList();
                          if (filter.isEmpty) return modules;
                          return modules.where((name) => name.toLowerCase().contains(filter.toLowerCase())).toList();
                        },
                        selectedItem: _selectedMergeTarget,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedMergeTarget = value;
                          });
                        },
                        dropdownBuilder: (context, selectedItem) {
                          return InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Select Target Module',
                              labelStyle: TextStyle(color: ColorWheel.primaryText),
                              filled: true,
                              fillColor: ColorWheel.secondaryBackground,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: ColorWheel.inputFieldPadding,
                            ),
                            child: Text(
                              selectedItem ?? '',
                              style: const TextStyle(color: ColorWheel.primaryText),
                            ),
                          );
                        },
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          constraints: const BoxConstraints(maxHeight: 300),
                          showSelectedItems: true,
                          fit: FlexFit.loose,
                          menuProps: MenuProps(
                            backgroundColor: ColorWheel.secondaryBackground,
                            borderRadius: ColorWheel.cardBorderRadius,
                            elevation: 4,
                          ),
                          itemBuilder: (context, item, isSelected, isDisabled) {
                            return Container(
                              color: isSelected ? ColorWheel.accent.withAlpha((0.15 * 255).toInt()) : ColorWheel.secondaryBackground,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: isSelected ? ColorWheel.accent : ColorWheel.primaryText,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                          searchFieldProps: TextFieldProps(
                            autofocus: true,
                            style: const TextStyle(color: ColorWheel.primaryText),
                            cursorColor: ColorWheel.primaryText,
                            decoration: InputDecoration(
                              hintText: 'Search modules...',
                              hintStyle: const TextStyle(color: ColorWheel.primaryText),
                              filled: true,
                              fillColor: ColorWheel.secondaryBackground,
                              border: OutlineInputBorder(
                                borderRadius: ColorWheel.cardBorderRadius,
                                borderSide: const BorderSide(color: ColorWheel.primaryBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: ColorWheel.cardBorderRadius,
                                borderSide: const BorderSide(color: ColorWheel.primaryBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: ColorWheel.cardBorderRadius,
                                borderSide: const BorderSide(color: ColorWheel.accent),
                              ),
                              contentPadding: ColorWheel.inputFieldPadding,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ColorWheel.formFieldSpacing),
                  if (_selectedMergeTarget != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _mergeModule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorWheel.buttonError,
                          foregroundColor: ColorWheel.primaryText,
                          shape: RoundedRectangleBorder(
                            borderRadius: ColorWheel.buttonBorderRadius,
                          ),
                          padding: ColorWheel.buttonPadding,
                        ),
                        child: const Text('Merge Module', style: ColorWheel.buttonTextBold),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
