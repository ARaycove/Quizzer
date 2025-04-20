// TODO [Module Access Control]
// Implement role-based access control for module editing:
// - Create user role system (admin, editor, viewer)
// - Add role check before enabling edit functionality
// - Disable edit buttons for users without proper permissions
// - Show appropriate messaging for unauthorized users
// - Add role management UI for admins

// TODO [Module Viewing Enhancement]
// Convert edit dialog to a view/edit dialog:
// - Rename to ModuleDetailsDialog
// - Show all module details in view mode by default
// - Only show edit controls for authorized users
// - Add tabs or sections for different types of information
// - Improve question display format

// TODO [Question Display Enhancement]
// Show actual question content instead of IDs:
// - Create a question preview component
// - Add pagination for questions
// - Include search/filter for questions
// - Show question stats and metadata
// - Add quick actions for questions (view, edit, delete)

// TODO [Question Management]
// Add question editing capabilities:
// - Create question edit interface
// - Add validation for edits
// - Implement edit history tracking
// - Add bulk edit capabilities
// - Include review system for edits
// - Handle question versioning

import 'package:flutter/material.dart';

class EditModuleDialog extends StatefulWidget {
  final Map<String, dynamic> moduleData;
  final Function(String) onSave;

  const EditModuleDialog({
    super.key,
    required this.moduleData,
    required this.onSave,
  });

  @override
  State<EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<EditModuleDialog> {
  late final TextEditingController _descriptionController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.moduleData['description'] ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.85 > 460 ? 460.0 : screenWidth * 0.85;
    final questionIds = widget.moduleData['question_ids'] as List<String>;

    return Dialog(
      backgroundColor: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Edit Module: ${widget.moduleData['module_name']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.grey),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description field
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      minLines: 3,
                      style: const TextStyle(color: Colors.grey),
                      decoration: InputDecoration(
                        hintText: 'Enter module description',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF0A1929),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Color.fromARGB(255, 71, 214, 93)),
                        ),
                        contentPadding: const EdgeInsets.all(12.0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Questions section
                    const Text(
                      'Questions in Module',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1929),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Questions: ${questionIds.length}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...questionIds.map((id) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  id,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Fixed footer with buttons
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Color(0xFF0A1929),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12.0),
                  bottomRight: Radius.circular(12.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(_descriptionController.text);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 