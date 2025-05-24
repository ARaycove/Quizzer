/*
Stats Page Description:
This page displays user statistics and learning progress.
Key features:
- Learning progress tracking
- Performance metrics
- Achievement display
- Progress visualization
*/ 
// TODO Setup and implement tracking and display of the following stats
// Single Stats
// Most things can be made into multi-day stats

// 3. 
// Multi-day Stats
// 1. eligible_questions (by date, to get current eligible questions get today's stat)
// 2. non_circulating_questions (by date, to get current non_circulating_questions get today's stat)
// 3. total_in_circulation_question (by date, to get current total_in_circulation_question)
// 4. revision_streak_stats (Records by date, the total number of questions categorized by revision_streak_score)
// 5. total_questions_in_database (by date, get the total number of user_question_answer_pairs that have at least one attempt on them)
// 6. average_questions_shown_per_day (by date, average number of questions being shown daily)
// 7. total_questions_answered (by date, the running the total of questions the users has answered)
// 8. questions_answered_by_date (by date, the number of questions the user answered on a given day)
// 9. reserve_questions_exhaust_in_x_days (single stat)
// - calculated by taking current non_circulating_questions (whose modules are active) and the average_num_questions_entering_circulation_daily
// - divide current non_circulating_questions / average_num_questions_entering_circulation_daily
// 10. average_num_questions_entering_circulation_daily
// - Need to analyze the historical record of total_in_circulation_questions and look at average increase over a one year cycle

import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'widget_graph_template.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<List<Map<String, dynamic>>> eligibleQuestionsHistoryFuture;
  late Future<Map<String, dynamic>?> currentEligibleQuestionsFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    eligibleQuestionsHistoryFuture = session.getEligibleQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    currentEligibleQuestionsFuture = session.getEligibleQuestionsStats().then((value) => value as Map<String, dynamic>?);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorWheel.primaryBackground,
      appBar: GlobalAppBar(
        title: 'Stats',
        showHomeButton: true,
      ),
      body: Padding(
        padding: ColorWheel.standardPadding,
        child: ListView(
          children: [
            // Current Eligible Questions
            FutureBuilder<Map<String, dynamic>?>(
              future: currentEligibleQuestionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stat = snapshot.data;
                final int currentEligible = stat != null ? (stat['eligible_questions_count'] as int? ?? 0) : 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Eligible Questions: $currentEligible',
                      style: ColorWheel.titleText,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            // Graph of Historical Eligible Questions
            FutureBuilder<List<Map<String, dynamic>>>(
              future: eligibleQuestionsHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
                // Map to expected format for StatLineGraph
                final graphData = history.map((e) => {
                  'date': e['record_date'] ?? '',
                  'value': e['eligible_questions_count'] ?? 0,
                }).toList();
                return StatLineGraph(
                  data: graphData,
                  title: 'Eligible Questions Over Time',
                  legendLabel: 'Eligible Questions',
                );
              },
            ),
            const SizedBox(height: 32),
            // Placeholder for other stats
            const Text(
              'Other stats coming soon...',
              style: ColorWheel.defaultText,
            ),
          ],
        ),
      ),
    );
  }
}