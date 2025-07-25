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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'scroll',
      mini: true,
      onPressed: showScrollToTop ? _scrollToTop : null,
      tooltip: 'Scroll to Top',
      child: const Icon(Icons.arrow_upward),
    );
  }
} 