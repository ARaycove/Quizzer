import 'package:flutter/material.dart';

class WidgetBooleanSettingTemplate extends StatefulWidget {
  final String settingName;
  final String displayName;
  final bool initialValue;
  final Future<void> Function(bool newValue) onSave;

  const WidgetBooleanSettingTemplate({
    super.key,
    required this.settingName,
    required this.displayName,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<WidgetBooleanSettingTemplate> createState() => _WidgetBooleanSettingTemplateState();
}

class _WidgetBooleanSettingTemplateState extends State<WidgetBooleanSettingTemplate> {
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant WidgetBooleanSettingTemplate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _currentValue = widget.initialValue;
    }
  }

  Future<void> _handleToggle(bool? newValue) async {
    if (newValue == null || newValue == _currentValue) return;
    
    // Update UI immediately for instant feedback
    setState(() {
      _currentValue = newValue;
    });
    
    // Handle the save operation in the background
    try {
      await widget.onSave(newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.displayName} updated successfully.')),
        );
      }
    } catch (e) {
      // Revert on failure
      setState(() {
        _currentValue = !newValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ${widget.displayName}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          Expanded(
            child: Text(widget.displayName),
          ),
          Checkbox(
            value: _currentValue,
            onChanged: _handleToggle,
          ),
        ],
      ),
    );
  }
}
