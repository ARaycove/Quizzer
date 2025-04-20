import 'package:flutter/material.dart';

class ModuleFilterButton extends StatelessWidget {
  final VoidCallback? onFilterPressed;

  const ModuleFilterButton({
    super.key,
    this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'filter',
      mini: true,
      backgroundColor: const Color(0xFF1E2A3A),
      onPressed: onFilterPressed ?? () {
        // TODO: Implement default filter functionality
      },
      child: const Icon(Icons.filter_list, color: Colors.white),
    );
  }
} 