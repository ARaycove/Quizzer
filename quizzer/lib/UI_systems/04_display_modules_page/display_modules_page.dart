import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_page_main_body_list.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_scroll_to_top_button.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/widget_module_filter_button.dart';
import 'package:quizzer/app_theme.dart';

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

    }

    void showInfoDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text('How to Navigate Modules'),
              ],
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Modules are organized by categories to help you find what you need:',
                  ),
                  AppTheme.sizedBoxMed,
                  Text('• Click any category header to expand and see modules'),
                  AppTheme.sizedBoxSml,
                  Text('• Modules may appear in multiple categories'),
                  AppTheme.sizedBoxSml,
                  Text('• Exam categories (CLEP, MCAT) are loosely ordered from basic to advanced'),
                  AppTheme.sizedBoxSml,
                  Text('• Within each category, modules go from basic to advanced (e.g., addition before calculus)'),
                  AppTheme.sizedBoxMed,
                  Text(
                    'Categories include:',
                  ),
                  AppTheme.sizedBoxSml,
                  Text('• MATHEMATICS - Math-related modules'),
                  AppTheme.sizedBoxSml,
                  Text('• CLEP - College Level Examination Program'),
                  AppTheme.sizedBoxSml,
                  Text('• MCAT - Medical College Admission Test'),
                  AppTheme.sizedBoxSml,
                  Text('• OTHER - General or uncategorized modules'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it!'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Modules',
        showHomeButton: true,
      ),
      body: Stack(
        children: [
          // Main content (module cards list) with error isolation
          Positioned.fill(
            child: Builder(
              builder: (context) {
                try {
                  return ModulePageMainBodyList(
                    scrollController: scrollController,
                  );
                } catch (e, stack) {
                  // Log the error if needed
                  debugPrint('ModulePageMainBodyList error: $e\n$stack');
                  return const Center(
                    child: Text(
                      'An error occurred in the main body widget.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }
              },
            ),
          ),
          // Top left info button
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: showInfoDialog,
              tooltip: 'How to navigate modules',
            ),
          ),
          // Top right action buttons (always visible)
          Positioned(
            top: 0,
            right: 0,
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
                AppTheme.sizedBoxMed,
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