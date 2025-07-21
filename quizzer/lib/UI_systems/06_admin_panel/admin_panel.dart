import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/06_admin_panel/widget_review_panel.dart';
import 'package:quizzer/UI_systems/06_admin_panel/widget_review_subjects_panel.dart';
import 'package:quizzer/UI_systems/06_admin_panel/widget_review_reported_questions.dart';

enum AdminPanel { none, review, reviewReported, reviewSubjects }

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  AdminPanel _selectedPanel = AdminPanel.none;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Admin Panel',
        showHomeButton: true,
      ),
      body: Stack(
        children: [
          // Main content area
          Positioned.fill(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildPanelButton(
                        label: 'Review add/edit',
                        panel: AdminPanel.review,
                      ),
                    ),
                    AppTheme.sizedBoxSml,
                    Expanded(
                      child: _buildPanelButton(
                        label: 'Review Reported Questions',
                        panel: AdminPanel.reviewReported,
                      ),
                    ),
                    AppTheme.sizedBoxSml,
                    Expanded(
                      child: _buildPanelButton(
                        label: 'Review Subjects',
                        panel: AdminPanel.reviewSubjects,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _buildCurrentPanelWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton({required String label, required AdminPanel panel}) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPanel = panel;
        });
      },
      child: Text(label),
    );
  }

  Widget _buildCurrentPanelWidget() {
    switch (_selectedPanel) {
      case AdminPanel.review:
        return const ReviewPanelWidget();
      case AdminPanel.reviewReported:
        return const ReviewReportedQuestionsPanelWidget();
      case AdminPanel.reviewSubjects:
        return const ReviewSubjectsPanelWidget();
      case AdminPanel.none:
        return const Center(
          child: Text('Select a panel above'),
        );
    }
  }
}
