import 'package:flutter/material.dart';

/// A custom button for editing module metadata
class EditModuleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const EditModuleButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
     final elementHeight = MediaQuery.of(context).size.height * 0.04;
     final elementHeight25px = elementHeight > 25.0 ? 25.0 : elementHeight;

    return SizedBox(
      height: elementHeight25px, // Apply max height
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit Module',
      ),
    );
  }
}
