import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
      backgroundColor: ColorWheel.secondaryBackground,
      onPressed: onFilterPressed ?? () {
        // TODO: Implement default filter functionality
      },
      tooltip: 'Filter Modules',
      child: const Icon(Icons.filter_list, color: ColorWheel.primaryText),
    );
  }
} 