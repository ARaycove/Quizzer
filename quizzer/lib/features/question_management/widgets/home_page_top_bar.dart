import 'package:flutter/material.dart';

class HomePageTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  final bool showFlagDialog;
  final TextEditingController flagController;
  final VoidCallback onSubmitFlag;
  // TODO When OnSubmitFlag is called we need to do the following:
  // 1. provide error handling for UI, If the field is empty do not proceed, but do not notify the user, if the field is not empty proceed with next steps
  // 2. Spin up an isolate, the function of the isolate will be as follows: take the data from the field, add it to the submitted flags table. You should read the submit flag table and ensure all fields are filled out
  // 3. Isolate is an async process not an isolate, just need to incorporate the DB call
  final VoidCallback onCancelFlag;

  const HomePageTopBar({
    super.key,
    required this.onMenuPressed,
    required this.showFlagDialog,
    required this.flagController,
    required this.onSubmitFlag,
    required this.onCancelFlag,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppBar(
          backgroundColor: const Color(0xFF0A1929),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onMenuPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white),
              onPressed: () {
                // Show flag dialog
                showDialog(
                  context: context,
                  builder: (context) => _buildFlagDialog(context),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // Helper to build the flag dialog
  Widget _buildFlagDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1929),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 145, 236, 247),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Flag Question",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: flagController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Please explain the issue with this question...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      onCancelFlag();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: onSubmitFlag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 71, 214, 93),
                    ),
                    child: const Text("Submit Flag"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 