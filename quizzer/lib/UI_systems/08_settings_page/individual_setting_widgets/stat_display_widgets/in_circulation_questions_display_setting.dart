import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/08_settings_page/widget_boolean_setting_template.dart';
import 'package:quizzer/UI_systems/UI_Utils/initial_state_helpers.dart';

class InCirculationQuestionsDisplaySetting extends StatefulWidget {
  const InCirculationQuestionsDisplaySetting({super.key});

  @override
  State<InCirculationQuestionsDisplaySetting> createState() => _InCirculationQuestionsDisplaySettingState();
}

class _InCirculationQuestionsDisplaySettingState extends State<InCirculationQuestionsDisplaySetting> {
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
      final dynamic fetchedValue = await _sessionManager.getUserSettings(settingName: 'home_display_in_circulation_questions');
      _isEnabled = convertToBoolean(fetchedValue);
    } catch (e) {
      _isEnabled = false;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleSave(bool newValue) async {
    // Fire and forget - don't await the response
    _sessionManager.updateUserSetting('home_display_in_circulation_questions', newValue);
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
              child: Text('In Circulation Questions Count'),
            ),
            CircularProgressIndicator(),
          ],
        ),
      );
    }

    return WidgetBooleanSettingTemplate(
      settingName: 'home_display_in_circulation_questions',
      displayName: 'In Circulation Questions Count',
      initialValue: _isEnabled,
      onSave: _handleSave,
    );
  }
} 