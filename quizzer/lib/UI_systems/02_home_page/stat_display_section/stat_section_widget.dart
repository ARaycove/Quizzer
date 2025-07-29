import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/02_home_page/stat_display_section/stat_display_template.dart';
import 'package:quizzer/UI_systems/UI_Utils/initial_state_helpers.dart';

class StatSectionWidget extends StatefulWidget {
  final VoidCallback? onRefresh; // Callback to trigger refresh from parent

  const StatSectionWidget({
    super.key,
    this.onRefresh,
  });

  @override
  State<StatSectionWidget> createState() => _StatSectionWidgetState();
}

class _StatSectionWidgetState extends State<StatSectionWidget> {
  final SessionManager _sessionManager = getSessionManager();
  Map<String, bool> _enabledSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Method to refresh stats - can be called from parent
  void refreshStats() {
    setState(() {
      // This will trigger a rebuild with the latest cached values
    });
  }

  Future<void> _loadSettings() async {
    try {
      // Check if cache has the required settings
      final cachedSettings = _sessionManager.cachedUserSettings;
      bool needsCacheFill = false;
      
      if (cachedSettings.isEmpty) {
        needsCacheFill = true;
      } else {
        // Check if all required settings are in cache
        final requiredSettings = [
          'home_display_eligible_questions',
          'home_display_in_circulation_questions',
          'home_display_non_circulating_questions',
          'home_display_lifetime_total_questions_answered',
          'home_display_daily_questions_answered',
          'home_display_average_daily_questions_learned',
          'home_display_average_questions_shown_per_day',
          'home_display_days_left_until_questions_exhaust',
          'home_display_revision_streak_score',
          'home_display_last_reviewed',
        ];
        
        for (final setting in requiredSettings) {
          if (!cachedSettings.containsKey(setting)) {
            needsCacheFill = true;
            break;
          }
        }
      }
      
      // Fill cache if needed
      if (needsCacheFill) {
        await _sessionManager.getUserSettings(getAll: true);
      }
      
      // Now use the cached values
      final settings = _sessionManager.cachedUserSettings;
      setState(() {
        _enabledSettings = {
          'home_display_eligible_questions': convertToBoolean(settings['home_display_eligible_questions']),
          'home_display_in_circulation_questions': convertToBoolean(settings['home_display_in_circulation_questions']),
          'home_display_non_circulating_questions': convertToBoolean(settings['home_display_non_circulating_questions']),
          'home_display_lifetime_total_questions_answered': convertToBoolean(settings['home_display_lifetime_total_questions_answered']),
          'home_display_daily_questions_answered': convertToBoolean(settings['home_display_daily_questions_answered']),
          'home_display_average_daily_questions_learned': convertToBoolean(settings['home_display_average_daily_questions_learned']),
          'home_display_average_questions_shown_per_day': convertToBoolean(settings['home_display_average_questions_shown_per_day']),
          'home_display_days_left_until_questions_exhaust': convertToBoolean(settings['home_display_days_left_until_questions_exhaust']),
          'home_display_revision_streak_score': convertToBoolean(settings['home_display_revision_streak_score']),
          'home_display_last_reviewed': convertToBoolean(settings['home_display_last_reviewed']),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is double) {
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  // Check if any cached values are null/N/A and update caches if needed
  Future<void> _checkAndUpdateCaches() async {
    // Check if any values are null
    if (_sessionManager.cachedEligibleQuestionsCount          == null || 
        _sessionManager.cachedInCirculationQuestionsCount     == null || 
        _sessionManager.cachedNonCirculatingQuestionsCount    == null ||
        _sessionManager.cachedLifetimeTotalQuestionsAnswered  == null || 
        _sessionManager.cachedDailyQuestionsAnswered          == null || 
        _sessionManager.cachedAverageDailyQuestionsLearned    == null || 
        _sessionManager.cachedAverageQuestionsShownPerDay     == null ||
        _sessionManager.cachedDaysLeftUntilQuestionsExhaust   == null || 
        _sessionManager.cachedRevisionStreakScore             == null
        ) {
      try {
        await _sessionManager.updateCaches();
        setState(() {
          // Trigger rebuild to show updated values
        });
      } catch (e) {
        // Ignore errors, will try again on next build
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return '${date.month}/${date.day}/${date.year % 100}';
  }

  List<Widget> _buildStatWidgets() {
    final List<Widget> widgets = [];

    // Eligible Questions
    if (_enabledSettings['home_display_eligible_questions'] == true) {
      final count = _sessionManager.cachedEligibleQuestionsCount;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(count),
          display: Icons.check_circle,
          tooltip: 'Questions ready to review',
        ),
      );
    }

    // In Circulation Questions
    if (_enabledSettings['home_display_in_circulation_questions'] == true) {
      final count = _sessionManager.cachedInCirculationQuestionsCount;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(count),
          display: Icons.rotate_right,
          tooltip: 'Questions currently in rotation',
        ),
      );
    }

    // Non-Circulating Questions
    if (_enabledSettings['home_display_non_circulating_questions'] == true) {
      final count = _sessionManager.cachedNonCirculatingQuestionsCount;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(count),
          display: Icons.pause_circle_outline,
          tooltip: 'Questions paused from rotation',
        ),
      );
    }

    // Lifetime Total Questions Answered
    if (_enabledSettings['home_display_lifetime_total_questions_answered'] == true) {
      final count = _sessionManager.cachedLifetimeTotalQuestionsAnswered;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(count),
          display: Icons.quiz,
          tooltip: 'Total questions answered',
        ),
      );
    }

    // Daily Questions Answered
    if (_enabledSettings['home_display_daily_questions_answered'] == true) {
      final count = _sessionManager.cachedDailyQuestionsAnswered;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(count),
          display: Icons.today,
          tooltip: 'Questions answered today',
        ),
      );
    }

    // Average Daily Questions Learned
    if (_enabledSettings['home_display_average_daily_questions_learned'] == true) {
      final avg = _sessionManager.cachedAverageDailyQuestionsLearned;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(avg),
          display: Icons.trending_up,
          tooltip: 'Average questions learned per day',
        ),
      );
    }

    // Average Questions Shown Per Day
    if (_enabledSettings['home_display_average_questions_shown_per_day'] == true) {
      final avg = _sessionManager.cachedAverageQuestionsShownPerDay;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(avg),
          display: Icons.visibility,
          tooltip: 'Average questions shown per day',
        ),
      );
    }

    // Days Left Until Questions Exhaust
    if (_enabledSettings['home_display_days_left_until_questions_exhaust'] == true) {
      final days = _sessionManager.cachedDaysLeftUntilQuestionsExhaust;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(days),
          display: Icons.schedule,
          tooltip: 'Days until questions exhaust',
        ),
      );
    }

    // Revision Streak Score
    if (_enabledSettings['home_display_revision_streak_score'] == true) {
      final streak = _sessionManager.cachedRevisionStreakScore;
      widgets.add(
        StatDisplayTemplate(
          value: _formatValue(streak),
          display: Icons.local_fire_department,
          tooltip: 'Current revision streak',
        ),
      );
    }

    // Last Reviewed Date
    if (_enabledSettings['home_display_last_reviewed'] == true) {
      final date = _sessionManager.cachedLastReviewed;
      widgets.add(
        StatDisplayTemplate(
          value: _formatDate(date),
          display: Icons.history,
          tooltip: 'Last reviewed date',
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check and update caches if needed
    _checkAndUpdateCaches();

    final statWidgets = _buildStatWidgets();
    
    if (statWidgets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statWidgets,
    );
  }
}
