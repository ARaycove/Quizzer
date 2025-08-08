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
      onPressed: onFilterPressed ?? () {
      },
      tooltip: 'Filter Modules',
      child: const Icon(Icons.filter_list),
    );
  }
} 