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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (display is IconData) ...[
            Icon(display),
          ],
          if (display is String) ...[
            Text(display),
          ],
          Text(value),
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
