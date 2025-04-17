import 'package:flutter/material.dart';

/// A custom button for adding a module to user profile
class AddModuleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isAdded;

  const AddModuleButton({
    super.key,
    required this.onPressed,
    this.isAdded = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.04, // Max 25px as per guidelines
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isAdded ? Icons.check_circle : Icons.add_circle_outline,
          color: isAdded 
            ? const Color(0xFF4CAF50) // Accent color from guidelines
            : Colors.white,
        ),
        tooltip: isAdded ? 'Added to Profile' : 'Add to Profile',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}

/// A custom button for editing module metadata
class EditModuleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const EditModuleButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.04, // Max 25px as per guidelines
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
        ),
        tooltip: 'Edit Module',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}

/// A row containing both module action buttons
class ModuleActionButtons extends StatelessWidget {
  final VoidCallback onAddPressed;
  final VoidCallback onEditPressed;
  final bool isAdded;

  const ModuleActionButtons({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    this.isAdded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AddModuleButton(
          onPressed: onAddPressed,
          isAdded: isAdded,
        ),
        const SizedBox(width: 8), // Spacing between buttons as per guidelines
        EditModuleButton(
          onPressed: onEditPressed,
        ),
      ],
    );
  }
} 