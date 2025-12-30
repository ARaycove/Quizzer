import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/08_settings_page/widget_setting_template.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';

class GeminiApiKeySetting extends StatefulWidget {
  const GeminiApiKeySetting({super.key});

  @override
  State<GeminiApiKeySetting> createState() => _GeminiApiKeySettingState();
}

class _GeminiApiKeySettingState extends State<GeminiApiKeySetting> {
  String _apiKey = ''; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final dynamic fetchedValue = await SessionManager().settings.getUserSettings(settingName: 'geminiApiKey');
      if (fetchedValue is String) {
        _apiKey = fetchedValue;
      } else {
        _apiKey = ''; // Default to empty if null or not a string
      }
    } catch (e) {
      // Handle potential errors during fetch, e.g., log or show a message
      _apiKey = ''; // Default on error
      debugPrint('Error loading Gemini API Key: $e'); // Or use QuizzerLogger
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleSaveApiKey(String newApiKey) async {
    // SessionManager.updateUserSetting will throw on failure which WidgetSettingTemplate can catch.
    await SessionManager().settings.updateUserSetting('geminiApiKey', newApiKey);
    // If successful, the template will update its own display value.
    // We update our local _apiKey as well for immediate UI consistency if needed, though
    // WidgetSettingTemplate usually re-renders with initialValue which should come from _loadApiKey upon next interaction.
    // For settings that are frequently re-read, this setState might be good.
    // However, the template itself gets the new value via its controller.
    // If we want to ensure this widget's _apiKey is also up-to-date immediately *without* a full reload/re-fetch,
    // then this setState is useful.
    setState(() {
      _apiKey = newApiKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return WidgetSettingTemplate(
      settingName: 'Gemini API Key',
      initialValue: _apiKey, 
      onSave: _handleSaveApiKey,
      isSensitiveData: false, // Hey monkey, don't tell me to consider if this should be true, fucking asshole.
    );
  }
}
