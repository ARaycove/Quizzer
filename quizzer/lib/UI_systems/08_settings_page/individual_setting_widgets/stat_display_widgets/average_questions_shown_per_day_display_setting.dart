import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/08_settings_page/widget_boolean_setting_template.dart';
import 'package:quizzer/UI_systems/UI_Utils/initial_state_helpers.dart';

class AverageQuestionsShownPerDayDisplaySetting extends StatefulWidget {
  const AverageQuestionsShownPerDayDisplaySetting({super.key});

  @override
  State<AverageQuestionsShownPerDayDisplaySetting> createState() => _AverageQuestionsShownPerDayDisplaySettingState();
}

class _AverageQuestionsShownPerDayDisplaySettingState extends State<AverageQuestionsShownPerDayDisplaySetting> {
  bool _isEnabled = false;
  bool _isLoading = true;
  final SessionManager _sessionManager = getSessionManager();

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final dynamic fetchedValue = await _sessionManager.getUserSettings(settingName: 'home_display_average_questions_shown_per_day');
      _isEnabled = convertToBoolean(fetchedValue);
    } catch (e) {
      _isEnabled = false;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleSave(bool newValue) async {
    await _sessionManager.updateUserSetting('home_display_average_questions_shown_per_day', newValue);
    setState(() {
      _isEnabled = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Row(
          children: [
            Expanded(
              child: Text('Average Questions Shown Per Day'),
            ),
            CircularProgressIndicator(),
          ],
        ),
      );
    }

    return WidgetBooleanSettingTemplate(
      settingName: 'home_display_average_questions_shown_per_day',
      displayName: 'Average Questions Shown Per Day',
      initialValue: _isEnabled,
      onSave: _handleSave,
    );
  }
} 