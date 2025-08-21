import 'package:flutter/material.dart';

class QuizzerBackground extends StatefulWidget {
  final FocusNode? focusNode;

  const QuizzerBackground({super.key, this.focusNode});

  @override
  State<QuizzerBackground> createState() => _QuizzerBackgroundState();
}

class _QuizzerBackgroundState extends State<QuizzerBackground> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleTap() {
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Focus(
        focusNode: _focusNode,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('images/quizzer_assets/quizzer_logo.png'),
              fit: BoxFit.contain,
              opacity: 0.1,
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}