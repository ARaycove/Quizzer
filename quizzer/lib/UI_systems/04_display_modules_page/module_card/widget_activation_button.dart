import 'package:flutter/material.dart';

/// A custom button for activating or deactivating a module
class ActivateOrDeactivateModuleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const ActivateOrDeactivateModuleButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  State<ActivateOrDeactivateModuleButton> createState() => _ActivateOrDeactivateModuleButtonState();
}

class _ActivateOrDeactivateModuleButtonState extends State<ActivateOrDeactivateModuleButton> {
  late bool _isActivated;

  @override
  void initState() {
    super.initState();
    _isActivated = widget.isActive;
  }

  void _handlePress() {
    // Call the callback first
    widget.onPressed();
    
    // Then toggle the internal state
    setState(() {
      _isActivated = !_isActivated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final elementHeight = MediaQuery.of(context).size.height * 0.04;
    final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;
    
    return SizedBox(
      height: elementHeight25px, // Apply max height
      child: IconButton(
        onPressed: _handlePress,
        icon: Icon(
          _isActivated ? Icons.check_circle : Icons.add_circle_outline,
        ),
        tooltip: _isActivated ? 'Module Activated' : 'Activate Module',
      ),
    );
  }
}
