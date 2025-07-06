/*
Stats Page Description:
This page displays user statistics and learning progress.
Key features:
- Learning progress tracking
- Performance metrics
- Achievement display
- Progress visualization
*/ 

import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'stat_widgets/eligible_questions_stat_widget.dart';
import 'stat_widgets/circulation_status_stat_widget.dart';
import 'stat_widgets/revision_score_stat_widget.dart';
import 'stat_widgets/total_question_pairs_stat_widget.dart';
import 'stat_widgets/average_questions_shown_stat_widget.dart';
import 'stat_widgets/total_questions_answered_stat_widget.dart';
import 'stat_widgets/daily_questions_answered_stat_widget.dart';
import 'stat_widgets/average_daily_questions_learned_stat_widget.dart';
import 'stat_widgets/days_left_until_exhaust_stat_widget.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: const GlobalAppBar(
        title: 'Stats',
        showHomeButton: true,
      ),
      body: Padding(
        padding: ColorWheel.standardPadding,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: const [
            AverageDailyQuestionsLearnedStatWidget(),
            DailyQuestionsAnsweredStatWidget(),
            TotalQuestionsAnsweredStatWidget(),
            RevisionScoreStatWidget(),
            CirculationStatusStatWidget(),
            TotalQuestionPairsStatWidget(),
            EligibleQuestionsStatWidget(),
            AverageQuestionsShownStatWidget(),
            DaysLeftUntilExhaustStatWidget(),
          ],
        ),
      ),
    );
  }
}