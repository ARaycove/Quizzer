import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // For Timer
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/app_theme.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  String? _selectedCategory;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String _submitButtonText = "Submit Feedback";

  final List<String> _feedbackCategories = [
    "Bug Report",
    "Feature Suggestion",
    "Something Else"
  ];

  Future<void> _launchBuyMeACoffee() async {
    final Uri url = Uri.parse('https://buymeacoffee.com/quizer');
    if (!await launchUrl(url)) {
      QuizzerLogger.logError('Could not launch $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link. Please try again later.')),
        );
      }
    }
  }

  void _submitFeedback() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitButtonText = "THANKS!";
    });

    try {
      QuizzerLogger.logMessage(
          "Sending feedback via SessionManager: Category: $_selectedCategory, Feedback: ${_feedbackController.text}");
      SessionManager().submitUserFeedback(
        feedbackType: _selectedCategory!, // Assert non-null as it passed validation
        feedbackContent: _feedbackController.text.trim(),
      ); // The Future is intentionally not awaited here to avoid blocking UI
      QuizzerLogger.logSuccess("Feedback submission initiated via SessionManager.");

      // Reset form and show success message on successful submission
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitButtonText = "Submit Feedback";
          _selectedCategory = null;
          _feedbackController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully!')),
        );
      }
    } catch (e, stackTrace) {
      QuizzerLogger.logError(
          'Error submitting feedback via SessionManager: $e\nStack Trace: $stackTrace' 
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false; // Reset submitting state on error
          _submitButtonText = "Submit Feedback";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: ${e.toString()}')),
        );
      }
    } finally {
      // The Timer for UI reset is removed as setState for success/error handles it.
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Give Feedback!',
        showHomeButton: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "Thanks for Downloading Quizzer!\n\nI assume you're here to give feedback, maybe a bug, or a suggestion for a new feature. I look forward to hearing back. So long as you have an internet connection I'll be able to read whatever it is you submit. And if you're really enjoying the experience or would just like to help fund further development, I'd be grateful if you would donate using the Buy Me A Coffee link down below.\n\nThe aim of quizzer is to simplify and enhance the learning process, so certain features like building 'decks' or similar things that support cramming are just not intended functionality. Learning is lifelong endevour and quizzer is your companion on that endevour. So while I understand that you might be looking to just cram for that next test I'd highly encourage you to adopt a system that will help you retain what you've learned over the long term, not just long enough to pass that exam.\n\n Donations help keep quizzer free for users who can't afford it otherwise",
            ),
            AppTheme.sizedBoxLrg,
            const Text('Type of Feedback'),
            DropdownButton<String>(
              value: _selectedCategory,
              hint: const Text('Is this a Bug Report, A Feature, or something else?'),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: _feedbackCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            AppTheme.sizedBoxMed,
            TextField(
              controller: _feedbackController,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              decoration: const InputDecoration(
                labelText: 'What are you thinking?',
                hintText: 'Enter your feedback here...',
              ),
              maxLines: 5,
            ),
            AppTheme.sizedBoxLrg,
            Center(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: Text(_submitButtonText),
              ),
            ),
            AppTheme.sizedBoxLrg,
            Center(
              child: InkWell(
                onTap: _launchBuyMeACoffee,
                child: Image.asset(
                  'images/quizzer_assets/support_me.webp',
                  errorBuilder: (context, error, stackTrace) {
                    QuizzerLogger.logError('Failed to load support_me.webp: $error');
                    return const Text('Could not load image');
                  },
                ),
              ),
            ),
            AppTheme.sizedBoxLrg,
          ],
        ),
      ),
    );
  }
} 