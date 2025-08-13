import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/04_display_modules_page/module_card/widget_module_card.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
class ModulePageMainBodyList extends StatefulWidget {
  final ScrollController scrollController;

  const ModulePageMainBodyList({
    super.key,
    required this.scrollController,
  });

  @override
  State<ModulePageMainBodyList> createState() => _ModulePageMainBodyListState();
}

class _ModulePageMainBodyListState extends State<ModulePageMainBodyList> {
  final SessionManager session = SessionManager();
  late Future<Map<String, Map<String, dynamic>>> _modulesFuture;
  
  // Manual ordering system for categories and modules
  final List<Map<String, List<String>>> _manualCategoryOrdering = [
    {
      'mathematics': [
        'is even or odd',
        'basic addition',
        'basic subtraction',
        'basic multiplication',
        'basic division',
        'geometry',
        'algebra 1',
        'algebra 2',
        'college algebra',
        'pre-calculus',
        'trigonometry',
        'calculus 1',
        'calculus 2',
        'calculus 3',
        'linear algebra'
        ]
    },
    {
      'clep': [
        
        ]
    },
    {
      'mcat': [

        ]
    },

    {
      'other': [

      ]
    }
  ];
  
  // Track expanded categories
  final Set<String> _expandedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _loadModulesData();
  }

  void _loadModulesData() {
    _modulesFuture = session.getModuleData();
  }
  
  // Group modules by categories with manual ordering
  Map<String, List<MapEntry<String, Map<String, dynamic>>>> _groupModulesByCategories(
    Map<String, Map<String, dynamic>> modulesData
  ) {
    final Map<String, List<MapEntry<String, Map<String, dynamic>>>> categoryGroups = {};
    
    // Initialize all categories from manual ordering
    for (final categoryMap in _manualCategoryOrdering) {
      final categoryName = categoryMap.keys.first;
      categoryGroups[categoryName] = [];
    }
    
    // Group modules by their categories
    for (final moduleEntry in modulesData.entries) {
      final moduleData = moduleEntry.value;
      final List<String> categories = (moduleData['categories'] as List<dynamic>?)
          ?.cast<String>() ?? ['other'];
      
      // Add module to each of its categories
      for (final category in categories) {
        if (!categoryGroups.containsKey(category)) {
          categoryGroups[category] = [];
        }
        categoryGroups[category]!.add(moduleEntry);
      }
    }
    
    // Sort modules within each category
    for (final categoryName in categoryGroups.keys) {
      final manualOrder = _getManualOrderForCategory(categoryName);
      categoryGroups[categoryName] = _sortModulesInCategory(
        categoryGroups[categoryName]!, 
        manualOrder
      );
    }
    
    return categoryGroups;
  }
  
  // Get manual ordering for a specific category
  List<String> _getManualOrderForCategory(String categoryName) {
    for (final categoryMap in _manualCategoryOrdering) {
      if (categoryMap.containsKey(categoryName)) {
        return categoryMap[categoryName]!;
      }
    }
    return [];
  }
  
  // Sort modules within a category based on manual order + alphabetical fallback
  List<MapEntry<String, Map<String, dynamic>>> _sortModulesInCategory(
    List<MapEntry<String, Map<String, dynamic>>> modules,
    List<String> manualOrder
  ) {
    modules.sort((a, b) {
      final aIndex = manualOrder.indexOf(a.key);
      final bIndex = manualOrder.indexOf(b.key);
      
      // Both in manual order
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      
      // Only a in manual order
      if (aIndex != -1) {
        return -1;
      }
      
      // Only b in manual order
      if (bIndex != -1) {
        return 1;
      }
      
      // Neither in manual order - alphabetical
      return (a.value['module_name'] ?? '').toLowerCase()
          .compareTo((b.value['module_name'] ?? '').toLowerCase());
    });
    
    return modules;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          QuizzerLogger.logError('Error loading modules: ${snapshot.error}');
          return const Center(
            child: Text(
              'Error loading modules. Please try again.',
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text(
              'No data received',
            ),
          );
        }
        
        final modulesData = snapshot.data!;
        
        // Filter modules to only show those with questions
        final modulesWithQuestions = Map<String, Map<String, dynamic>>.fromEntries(
          modulesData.entries.where((entry) => (entry.value['total_questions'] ?? 0) > 0)
        );
        
        if (modulesWithQuestions.isEmpty) {
          return const Center(
            child: Text(
              'No modules with questions found',
            ),
          );
        }
        
        // Group modules by categories
        final categoryGroups = _groupModulesByCategories(modulesWithQuestions);
        
        // Filter out empty categories
        final nonEmptyCategories = categoryGroups.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList();
        
        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Add extra space at the top for the floating buttons
            const SizedBox(height: 40),
            ...nonEmptyCategories.map((categoryEntry) => _buildCategorySection(
              categoryEntry.key,
              categoryEntry.value,
            )),
          ],
        );
      },
    );
  }
  
  Widget _buildCategorySection(String categoryName, List<MapEntry<String, Map<String, dynamic>>> modules) {
    final isExpanded = _expandedCategories.contains(categoryName);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          ListTile(
            title: Text(
              categoryName.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${modules.length} modules'),
                const SizedBox(height: 4),
                Text(
                  _getCategoryDescription(categoryName),
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ],
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(categoryName);
                } else {
                  _expandedCategories.add(categoryName);
                }
              });
            },
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            ...modules.map((moduleEntry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ModuleCard(
                moduleData: moduleEntry.value,
                onModuleUpdated: () {
                  setState(() {
                    _loadModulesData();
                  });
                },
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  String _getCategoryDescription(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'mathematics':
        return 'This category contains modules from the most basic to the most advanced mathematics topics. From basic counting and addition to graduate level math.';
      case 'clep':
        return 'Modules that help you prepare and learn the content on College Level Examination Program tests.';
      case 'mcat':
        return 'Modules that help you prepare and learn the content on Medical College Admission Tests.';
      case 'other':
        return 'Anything not yet categorized and labeled. Here you\'ll find a miscellaneous selection of knowledge to learn.';
      default:
        return 'Modules in this category.';
    }
  }
}
