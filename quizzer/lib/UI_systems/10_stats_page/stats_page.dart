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
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<List<Map<String, dynamic>>> eligibleQuestionsHistoryFuture;
  late Future<Map<String, dynamic>?> currentEligibleQuestionsFuture;
  late Future<List<Map<String, dynamic>>> nonCirculatingQuestionsHistoryFuture;
  late Future<Map<String, dynamic>?> currentNonCirculatingQuestionsFuture;
  late Future<List<Map<String, dynamic>>> inCirculationQuestionsHistoryFuture;
  late Future<Map<String, dynamic>?> currentInCirculationQuestionsFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    eligibleQuestionsHistoryFuture = session.getEligibleQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    currentEligibleQuestionsFuture = session.getEligibleQuestionsStats().then((value) => value as Map<String, dynamic>?);
    nonCirculatingQuestionsHistoryFuture = session.getNonCirculatingQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    currentNonCirculatingQuestionsFuture = session.getNonCirculatingQuestionsStats().then((value) => value as Map<String, dynamic>?);
    inCirculationQuestionsHistoryFuture = session.getInCirculationQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    currentInCirculationQuestionsFuture = session.getInCirculationQuestionsStats().then((value) => value as Map<String, dynamic>?);
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
            // Eligible Questions Stat + Graph
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
                    const SizedBox(height: 8),
                    // Graph for Eligible Questions
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: eligibleQuestionsHistoryFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final history = snapshot.data ?? [];
                        final graphData = history.map((e) => {
                          'date': e['record_date'] ?? '',
                          'value': e['eligible_questions_count'] ?? 0,
                        }).toList();
                        return StatLineGraph(
                          data: graphData,
                          title: 'Eligible Questions Over Time',
                          legendLabel: 'Eligible Questions',
                          yAxisLabel: 'Eligible Questions',
                          xAxisLabel: 'Date',
                          lineColor: Colors.blue,
                          chartName: 'Eligible Questions Over Time',
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
            // Circulation Status Stat + Combined Graph
            FutureBuilder<List<List<Map<String, dynamic>>>>(
              future: Future.wait([
                nonCirculatingQuestionsHistoryFuture,
                inCirculationQuestionsHistoryFuture,
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final nonCircHistory = snapshot.data?[0] ?? [];
                final inCircHistory = snapshot.data?[1] ?? [];
                // Prepare data series
                final nonCircSeries = StatLineSeries(
                  legendLabel: 'Non-Circulating',
                  lineColor: Colors.orange,
                  data: nonCircHistory.map((e) => {
                    'date': e['record_date'] ?? '',
                    'value': e['non_circulating_questions_count'] ?? 0,
                  }).toList(),
                );
                final inCircSeries = StatLineSeries(
                  legendLabel: 'In Circulation',
                  lineColor: Colors.blue,
                  data: inCircHistory.map((e) => {
                    'date': e['record_date'] ?? '',
                    'value': e['in_circulation_questions_count'] ?? 0,
                  }).toList(),
                );
                return FutureBuilder<List<Map<String, dynamic>?>>(
                  future: Future.wait([
                    currentNonCirculatingQuestionsFuture,
                    currentInCirculationQuestionsFuture,
                  ]),
                  builder: (context, statSnapshot) {
                    if (statSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final nonCircStat = statSnapshot.data?[0];
                    final inCircStat = statSnapshot.data?[1];
                    final int currentNonCirc = nonCircStat != null ? (nonCircStat['non_circulating_questions_count'] as int? ?? 0) : 0;
                    final int currentInCirc = inCircStat != null ? (inCircStat['in_circulation_questions_count'] as int? ?? 0) : 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Non-Circulating Questions: $currentNonCirc',
                          style: ColorWheel.titleText,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current In Circulation Questions: $currentInCirc',
                          style: ColorWheel.titleText,
                        ),
                        const SizedBox(height: 8),
                        StatLineGraph.multi(
                          seriesList: [nonCircSeries, inCircSeries],
                          title: 'Circulation Status Over Time',
                          chartName: 'Circulation Status Over Time',
                          yAxisLabel: 'Questions',
                          xAxisLabel: 'Date',
                          showLegend: true,
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                );
              },
            ),
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