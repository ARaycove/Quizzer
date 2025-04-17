import 'package:flutter/material.dart';
import 'dart:math' as math;
// import 'package:quizzer/global/functionality/quizzer_logging.dart';

class HomePageCenterButton extends StatefulWidget {
  final List<Map<String, dynamic>> questionElements;
  final List<Map<String, dynamic>> answerElements;
  final VoidCallback onFlip;
  final bool isShowingAnswer;

  const HomePageCenterButton({
    super.key,
    required this.questionElements,
    required this.answerElements,
    required this.onFlip,
    required this.isShowingAnswer,
  });

  @override
  State<HomePageCenterButton> createState() => _HomePageCenterButtonState();
}

class _HomePageCenterButtonState extends State<HomePageCenterButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // QuizzerLogger.logMessage('HomePageCenterButton initState with question elements: ${widget.questionElements}');
    // QuizzerLogger.logMessage('HomePageCenterButton initState with answer elements: ${widget.answerElements}');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomePageCenterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // QuizzerLogger.logMessage('HomePageCenterButton didUpdateWidget with question elements: ${widget.questionElements}');
    // QuizzerLogger.logMessage('HomePageCenterButton didUpdateWidget with answer elements: ${widget.answerElements}');
    if (widget.isShowingAnswer != oldWidget.isShowingAnswer) {
      if (widget.isShowingAnswer) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // QuizzerLogger.logMessage('HomePageCenterButton building with question elements: ${widget.questionElements}');
    // QuizzerLogger.logMessage('HomePageCenterButton building with answer elements: ${widget.answerElements}');
    return GestureDetector(
      onTap: widget.onFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_animation.value * math.pi),
            child: _animation.value <= 0.5
                ? _buildCardContent(
                    widget.questionElements,
                    Colors.grey,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(math.pi),
                    child: _buildCardContent(
                      widget.answerElements,
                      const Color.fromARGB(255, 145, 236, 247),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(List<Map<String, dynamic>> elements, Color color) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Background logo
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                ),
                child: Image.asset(
                  "images/quizzer_assets/quizzer_logo.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: elements.map((element) {
                // QuizzerLogger.logMessage('Processing element: $element');
                switch (element['type']) {
                  case 'text':
                    return Text(
                      element['content'],
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    );
                  // Add cases for other element types (image, audio, video) as needed
                  default:
                    return const SizedBox.shrink();
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
} 