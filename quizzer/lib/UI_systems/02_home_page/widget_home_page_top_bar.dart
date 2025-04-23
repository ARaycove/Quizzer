import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

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
          backgroundColor: ColorWheel.primaryBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: ColorWheel.primaryText),
            onPressed: onMenuPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag, color: ColorWheel.primaryText),
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
          padding: const EdgeInsets.all(ColorWheel.majorSectionSpacing),
          decoration: BoxDecoration(
            color: ColorWheel.primaryBackground,
            borderRadius: ColorWheel.cardBorderRadius,
            border: Border.all(
              color: ColorWheel.textInputBackground,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Flag Question",
                style: ColorWheel.titleText,
              ),
              const SizedBox(height: ColorWheel.standardPaddingValue),
              TextField(
                controller: flagController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Please explain the issue with this question...",
                  hintStyle: ColorWheel.hintTextStyle.copyWith(color: Colors.grey[600]),
                  filled: true,
                  fillColor: ColorWheel.primaryText,
                  border: OutlineInputBorder(
                    borderRadius: ColorWheel.textFieldBorderRadius,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: ColorWheel.inputFieldPadding,
                ),
                style: ColorWheel.defaultText.copyWith(color: Colors.black),
              ),
              const SizedBox(height: ColorWheel.standardPaddingValue),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      onCancelFlag();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorWheel.buttonSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: ColorWheel.buttonBorderRadius,
                      ),
                    ),
                    child: const Text("Cancel", style: ColorWheel.buttonText),
                  ),
                  ElevatedButton(
                    onPressed: onSubmitFlag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorWheel.buttonSuccess,
                      shape: RoundedRectangleBorder(
                        borderRadius: ColorWheel.buttonBorderRadius,
                      ),
                    ),
                    child: const Text("Submit Flag", style: ColorWheel.buttonTextBold),
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