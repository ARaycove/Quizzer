import 'package:flutter/material.dart';

class StatDisplayTemplate extends StatelessWidget {
  final String value;
  final dynamic display; // Either String or IconData
  final String? tooltip;

  const StatDisplayTemplate({
    super.key,
    required this.value,
    required this.display,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Fixed width for icon (20px)
          SizedBox(
            width: 20,
            child: display is IconData 
              ? Icon(display)
              : display is String 
                ? Text(display)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 4), // Small gap between icon and value
          // Remaining space for the value (76px)
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: content,
      );
    }
    
    return content;
  }
}
