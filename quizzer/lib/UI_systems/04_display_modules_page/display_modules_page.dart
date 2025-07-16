import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_page_main_body_list.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_scroll_to_top_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_filter_button.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class DisplayModulesPage extends StatelessWidget {
  const DisplayModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    final ValueNotifier<bool> showScrollToTopNotifier = ValueNotifier<bool>(false);
    
    // Scroll listener
    void scrollListener() {
      if (scrollController.offset >= 100 && !showScrollToTopNotifier.value) {
        showScrollToTopNotifier.value = true;
      } else if (scrollController.offset < 100 && showScrollToTopNotifier.value) {
        showScrollToTopNotifier.value = false;
      }
    }
    
    scrollController.addListener(scrollListener);
    
    void handleFilter() {
      // TODO: Implement filter functionality
    }

    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: const GlobalAppBar(
        title: 'Modules',
        showHomeButton: true,
      ),
      body: Stack(
        children: [
          // Main content (module cards list)
          Positioned.fill(
            child: ModulePageMainBodyList(
              scrollController: scrollController,
            ),
          ),
          // Top action buttons (always visible)
          Positioned(
            top: ColorWheel.standardPaddingValue,
            right: ColorWheel.standardPaddingValue,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: showScrollToTopNotifier,
                  builder: (context, showScrollToTop, child) {
                    return ScrollToTopButton(
                      scrollController: scrollController,
                      showScrollToTop: showScrollToTop,
                    );
                  },
                ),
                const SizedBox(width: ColorWheel.formFieldSpacing),
                ModuleFilterButton(
                  onFilterPressed: handleFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}