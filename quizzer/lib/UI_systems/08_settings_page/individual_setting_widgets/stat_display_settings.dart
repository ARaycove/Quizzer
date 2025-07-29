import 'package:flutter/material.dart';
import 'package:quizzer/app_theme.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/eligible_questions_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/in_circulation_questions_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/non_circulating_questions_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/lifetime_total_questions_answered_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/daily_questions_answered_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/average_daily_questions_learned_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/average_questions_shown_per_day_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/days_left_until_questions_exhaust_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/revision_streak_score_display_setting.dart';
import 'package:quizzer/UI_systems/08_settings_page/individual_setting_widgets/stat_display_widgets/last_reviewed_display_setting.dart';

class StatDisplaySettings extends StatelessWidget {
  const StatDisplaySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // H2 header for the section
        Text(
          'Home Page Statistics Display',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppTheme.sizedBoxSml,
        const Text(
          'Toggle the statistics you want to display directly on the home page. '
          'When enabled, these stats will appear alongside your questions, '
          'allowing you to track your progress without navigating to the stats page.',
        ),
        AppTheme.sizedBoxLrg,
        const EligibleQuestionsDisplaySetting(),
        const InCirculationQuestionsDisplaySetting(),
        const NonCirculatingQuestionsDisplaySetting(),
        const LifetimeTotalQuestionsAnsweredDisplaySetting(),
        const DailyQuestionsAnsweredDisplaySetting(),
        const AverageDailyQuestionsLearnedDisplaySetting(),
        const AverageQuestionsShownPerDayDisplaySetting(),
        const DaysLeftUntilQuestionsExhaustDisplaySetting(),
        const RevisionStreakScoreDisplaySetting(),
        const LastReviewedDisplaySetting(),
      ],
    );
  }
}
