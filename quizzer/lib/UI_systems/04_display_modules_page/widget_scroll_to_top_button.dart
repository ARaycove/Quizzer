import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class ScrollToTopButton extends StatelessWidget {
  final ScrollController scrollController;
  final bool showScrollToTop;

  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    required this.showScrollToTop,
  });

  void _scrollToTop() {
    scrollController.animateTo(
      0,
      duration: ColorWheel.standardAnimationDuration,
      curve: ColorWheel.standardAnimationCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'scroll',
      mini: true,
      backgroundColor: ColorWheel.secondaryBackground,
      onPressed: showScrollToTop ? _scrollToTop : null,

      tooltip: 'Scroll to Top',
            child: Icon(
        Icons.arrow_upward,
        color: showScrollToTop ? ColorWheel.primaryText : ColorWheel.primaryText.withAlpha(128),
      ),
    );
  }
} 