import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/06_admin_panel/widget_categorization_panel.dart';
import 'package:quizzer/UI_systems/06_admin_panel/widget_review_panel.dart';

enum AdminPanel { none, review, categorize }

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
      backgroundColor: ColorWheel.primaryBackground,
      appBar: const GlobalAppBar(
        title: 'Admin Panel',
        showHomeButton: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(ColorWheel.standardPaddingValue / 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildPanelButton(
                    label: 'Review add/edit',
                    panel: AdminPanel.review,
                  ),
                ),
                const SizedBox(width: ColorWheel.standardPaddingValue / 2),
                Expanded(
                  child: _buildPanelButton(
                    label: 'Categorize',
                    panel: AdminPanel.categorize,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: ColorWheel.secondaryText),

          Expanded(
            child: _buildCurrentPanelWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton({required String label, required AdminPanel panel}) {
    final bool isActive = _selectedPanel == panel;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPanel = panel;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? ColorWheel.accent : ColorWheel.buttonSecondary,
        foregroundColor: ColorWheel.primaryText,
        shape: RoundedRectangleBorder(
          borderRadius: ColorWheel.buttonBorderRadius,
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildCurrentPanelWidget() {
    switch (_selectedPanel) {
      case AdminPanel.review:
        return const ReviewPanelWidget();
      case AdminPanel.categorize:
        return const CategorizationPanelWidget();
      case AdminPanel.none:
        return const Center(
          child: Text('Select a panel above', style: ColorWheel.secondaryTextStyle),
        );
    }
  }
}
