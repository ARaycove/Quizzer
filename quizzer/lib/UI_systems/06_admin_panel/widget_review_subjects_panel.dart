import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewSubjectsPanelWidget extends StatefulWidget {
  const ReviewSubjectsPanelWidget({super.key});

  @override
  State<ReviewSubjectsPanelWidget> createState() => _ReviewSubjectsPanelWidgetState();
}

class _ReviewSubjectsPanelWidgetState extends State<ReviewSubjectsPanelWidget> {
  final SessionManager _session = SessionManager();
  final TextEditingController _markdownController = TextEditingController();

  // Internal state variables
  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _primaryKey;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNextSubject();
  }

  @override
  void dispose() {
    _markdownController.dispose();
    super.dispose();
  }

  Future<void> _fetchNextSubject() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _session.getSubjectForReview();

    if (mounted) {
      setState(() {
        _currentData = result['data'] as Map<String, dynamic>?;
        _primaryKey = result['primary_key'] as Map<String, dynamic>?;
        _errorMessage = result['error'] as String?;
        _isLoading = false;
        
        // Set the description controller with current data
        if (_currentData != null) {
          final String? description = _currentData!['subject_description'] as String?;
          _markdownController.text = description ?? '';
        }
      });
    }
  }

  Future<void> _submitSubject() async {
    if (_currentData == null || _primaryKey == null) {
      QuizzerLogger.logWarning('Submit pressed but data is missing.');
      return;
    }
    
    QuizzerLogger.logMessage('Submitting subject update...');
    setState(() => _isLoading = true);

    // Create updated data with the edited description
    final Map<String, dynamic> updatedData = Map<String, dynamic>.from(_currentData!);
    updatedData['subject_description'] = _markdownController.text.trim();

    final success = await _session.updateReviewedSubject(updatedData, _primaryKey!);

    if (mounted) {
      if (success) {
        QuizzerLogger.logSuccess('Subject update successful, fetching next subject.');
        _fetchNextSubject(); // Fetch next on success
      } else {
        QuizzerLogger.logError('Subject update failed.');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to update subject.';
        });
      }
    }
  }

  Future<void> _skipSubject() async {
    QuizzerLogger.logMessage('Skipping subject...');
    _fetchNextSubject();
  }

  String _capitalizeSubject(String subject) {
    if (subject.isEmpty) return subject;
    
    // Replace underscores with spaces and convert to title case
    return subject
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  String _formatParentSubjects(dynamic parentSubjects) {
    if (parentSubjects == null) return 'ROOT';
    
    if (parentSubjects is List) {
      return parentSubjects.map((subject) => _capitalizeSubject(subject.toString())).join(', ');
    }
    
    return _capitalizeSubject(parentSubjects.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text('Error: $_errorMessage'),
      );
    }

    if (_currentData == null) {
      return const Center(
        child: Text('No subject data available.'),
      );
    }

    final String subject = _currentData!['subject'] as String? ?? '';
    final String capitalizedSubject = _capitalizeSubject(subject);
    final String parentSubjects = _formatParentSubjects(_currentData!['immediate_parent']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subject Information Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject
              Row(
                children: [
                  const Text('Subject: '),
                  Expanded(
                    child: Text(capitalizedSubject),
                  ),
                ],
              ),
              AppTheme.sizedBoxSml,
              // Parent Subjects
              Row(
                children: [
                  const Text('Parent Subjects: '),
                  Expanded(
                    child: Text(parentSubjects),
                  ),
                ],
              ),
            ],
          ),
          
          AppTheme.sizedBoxMed,
          
          // Description Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Subject Description:'),
              AppTheme.sizedBoxSml,
              
              // Markdown Editor
              Card(
                child: MarkdownAutoPreview(
                  controller: _markdownController,
                  emojiConvert: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  cursorColor: Theme.of(context).colorScheme.onSurface,
                  toolbarBackground: Theme.of(context).colorScheme.surface,
                  expandableBackground: Theme.of(context).colorScheme.surface,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
              AppTheme.sizedBoxSml,
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse('https://www.markdownguide.org/basic-syntax/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.help_outline),
                label: const Text('Markdown Guide'),
              ),
            ],
          ),
          
          AppTheme.sizedBoxMed,
          
          // Bottom Bar: Skip/Submit Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _skipSubject,
                child: const Text("Skip"),
              ),
              ElevatedButton(
                onPressed: _submitSubject,
                child: const Text("Submit"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
