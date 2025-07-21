import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';

class WidgetSettingTemplate extends StatefulWidget {
  final String settingName;
  final String initialValue;
  final Future<void> Function(String newValue) onSave;
  final bool isSensitiveData;

  const WidgetSettingTemplate({
    super.key,
    required this.settingName,
    required this.initialValue,
    required this.onSave,
    this.isSensitiveData = false,
  });

  @override
  State<WidgetSettingTemplate> createState() => _WidgetSettingTemplateState();
}

class _WidgetSettingTemplateState extends State<WidgetSettingTemplate> {
  late TextEditingController _textController;
  bool _isEditing = false;
  bool _isLoading = false;
  late String _currentValue;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _textController = TextEditingController(text: _currentValue);
  }

  @override
  void didUpdateWidget(covariant WidgetSettingTemplate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && !_isEditing) {
      _currentValue = widget.initialValue;
      _textController.text = _currentValue;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_textController.text == _currentValue) {
      setState(() {
        _isEditing = false;
      });
      _focusNode.unfocus();
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.onSave(_textController.text);
      setState(() {
        _currentValue = _textController.text;
        _isEditing = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.settingName} updated successfully.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ${widget.settingName}: $e')),
        );
      }
      // Optionally, keep editing mode active on failure or revert: _textController.text = _currentValue;
    }
    _focusNode.unfocus();
  }

  void _handleCancel() {
    setState(() {
      _textController.text = _currentValue; // Revert to original value
      _isEditing = false;
    });
    _focusNode.unfocus();
  }

  Widget _buildInteractiveRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _isEditing
              ? TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  obscureText: widget.isSensitiveData,
                  autofocus: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  onSubmitted: (_) => _handleSave(), // Save on Enter
                )
              : Text(
                  widget.isSensitiveData ? ('•' * _currentValue.length.clamp(0, 20)) : _currentValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        AppTheme.sizedBoxSml,
        if (_isEditing)
          Row(
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check),
                        AppTheme.sizedBoxSml,
                        Text('Submit'),
                      ],
                    ),
              ),
              AppTheme.sizedBoxSml,
              ElevatedButton(
                onPressed: _handleCancel,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel),
                    AppTheme.sizedBoxSml,
                    Text('Cancel'),
                  ],
                ),
              ),
            ],
          )
        else
          ElevatedButton(
            onPressed: () {
              setState(() {
                _textController.text = _currentValue;
                _isEditing = true;
              });
              // Request focus after a short delay to ensure TextField is built
              Future.delayed(const Duration(milliseconds: 50), () => _focusNode.requestFocus());
            },
            child: const Text('Edit'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.settingName),
        AppTheme.sizedBoxSml,
        _buildInteractiveRow(context),
      ],
    );
  }
}
