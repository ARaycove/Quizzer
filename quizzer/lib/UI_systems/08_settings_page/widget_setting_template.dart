import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
      decoration: BoxDecoration(
        color: ColorWheel.textInputBackground,
        borderRadius: ColorWheel.textFieldBorderRadius,
        // No explicit border here to reduce layering, relying on background contrast
      ),
      child: Row(
        children: [
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    obscureText: widget.isSensitiveData,
                    style: ColorWheel.defaultText.copyWith(color: ColorWheel.inputText),
                    decoration: const InputDecoration(
                      border: InputBorder.none, // No inner border for TextField itself
                      isDense: true, // To reduce height
                      contentPadding: EdgeInsets.symmetric(vertical: 10), // Adjust vertical padding
                    ),
                    autofocus: true,
                    onSubmitted: (_) => _handleSave(), // Save on Enter
                  )
                : Padding( // Added padding to Text for alignment with TextField
                    padding: const EdgeInsets.symmetric(vertical: 10.0), // Match TextField's effective height
                    child: Text(
                      widget.isSensitiveData ? ('•' * _currentValue.length.clamp(0, 20)) : _currentValue,
                      style: ColorWheel.defaultText.copyWith(color: ColorWheel.inputText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          if (_isEditing)
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.buttonSuccess,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjusted padding
                    shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 18, 
                        height: 18, 
                        child: CircularProgressIndicator(color: ColorWheel.primaryText, strokeWidth: 2)
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, color: ColorWheel.primaryText, size: 18),
                          const SizedBox(height: 1),
                          Text('Submit', style: ColorWheel.buttonText.copyWith(fontSize: 9)),
                        ],
                      ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorWheel.buttonError,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel, color: ColorWheel.primaryText, size: 18),
                      const SizedBox(height: 1),
                      Text('Cancel', style: ColorWheel.buttonText.copyWith(fontSize: 9)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorWheel.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Adjusted padding
                shape: RoundedRectangleBorder(borderRadius: ColorWheel.buttonBorderRadius),
              ),
              child: const Text('Edit', style: ColorWheel.buttonText),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.settingName,
            style: ColorWheel.titleText.copyWith(fontSize: 16, fontWeight: FontWeight.normal), // Made font normal to be less imposing
          ),
          const SizedBox(height: 6.0), // Reduced space
          _buildInteractiveRow(context),
        ],
      ),
    );
  }
}
