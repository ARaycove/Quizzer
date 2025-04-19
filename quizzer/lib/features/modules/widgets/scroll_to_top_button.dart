import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'scroll',
      mini: true,
      backgroundColor: const Color(0xFF1E2A3A),
      onPressed: showScrollToTop ? _scrollToTop : null,
      child: Icon(
        Icons.arrow_upward,
        color: showScrollToTop ? Colors.white : Colors.white.withAlpha(128),
      ),
    );
  }
} 