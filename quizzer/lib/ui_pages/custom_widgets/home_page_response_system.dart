import 'package:flutter/material.dart';

class HomePageResponseSystem extends StatelessWidget {
  final bool showOtherOptions;
  final bool buttonsEnabled;
  final VoidCallback onOtherOptionsToggle;
  final Function(String) onResponse;

  const HomePageResponseSystem({
    super.key,
    required this.showOtherOptions,
    required this.buttonsEnabled,
    required this.onOtherOptionsToggle,
    required this.onResponse,
  });

  @override
  Widget build(BuildContext context) {
    return showOtherOptions
        ? _buildOtherOptions()
        : buttonsEnabled
            ? _buildResponseButtons()
            : const SizedBox(height: 60); // Empty space when buttons not shown
  }

  // Helper to build the main response buttons row
  Widget _buildResponseButtons() {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          _buildResponseButton(
            "Yes(sure)",
            const Color.fromARGB(255, 71, 214, 93),
            "yes_sure",
          ),
          _buildResponseButton(
            "Yes(unsure)",
            const Color.fromARGB(255, 118, 214, 133),
            "yes_unsure",
          ),
          _buildResponseButton(
            "Other",
            Colors.grey,
            "other",
            isOtherButton: true,
          ),
          _buildResponseButton(
            "No(unsure)",
            const Color.fromARGB(255, 214, 118, 118),
            "no_unsure",
          ),
          _buildResponseButton(
            "No(sure)",
            const Color.fromARGB(255, 214, 71, 71),
            "no_sure",
          ),
        ],
      ),
    );
  }
  
  // Helper to build individual response button
  Widget _buildResponseButton(String label, Color color, String status, {bool isOtherButton = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ElevatedButton(
          onPressed: buttonsEnabled ? () {
            if (isOtherButton) {
              onOtherOptionsToggle();
            } else {
              onResponse(status);
            }
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // Helper to build the "Other" options
  Widget _buildOtherOptions() {
    return Container(
      height: 180, 
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        children: [
          // "Did not read..." button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 5.0),
              child: ElevatedButton(
                onPressed: buttonsEnabled ? () => onResponse("did_not_read") : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "Did Not Read the Question... Whoops",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // "Too advanced" button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              child: ElevatedButton(
                onPressed: buttonsEnabled ? () => onResponse("too_advanced") : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "This is TOO ADVANCED for me",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // "Not interested" button
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 5.0),
              child: ElevatedButton(
                onPressed: buttonsEnabled ? () => onResponse("not_interested") : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  "Just not interested in learning this",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // Back button
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: onOtherOptionsToggle,
              child: const Text(
                "Back to Response Options",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 