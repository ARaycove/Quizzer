import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_graph_template.dart';
import 'package:quizzer/app_theme.dart';

class AverageQuestionsShownStatWidget extends StatefulWidget {
  const AverageQuestionsShownStatWidget({super.key});

  @override
  State<AverageQuestionsShownStatWidget> createState() => _AverageQuestionsShownStatWidgetState();
}

class _AverageQuestionsShownStatWidgetState extends State<AverageQuestionsShownStatWidget> {
  late Future<Map<String, dynamic>?> currentAverageQuestionsShownPerDayFuture;
  late Future<List<Map<String, dynamic>>> historicalAverageQuestionsShownPerDayFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentAverageQuestionsShownPerDayFuture = session.getCurrentAverageQuestionsShownPerDayStat();
    historicalAverageQuestionsShownPerDayFuture = session.getHistoricalAverageQuestionsShownPerDayStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Average Questions Shown Per Day Stat
        FutureBuilder<Map<String, dynamic>?>(
          future: currentAverageQuestionsShownPerDayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stat = snapshot.data;
            final double avgShown = stat != null ? (stat['average_questions_shown_per_day'] as double? ?? 0.0) : 0.0;
            return Text(
              'Current Average Questions Shown Per Day: ${avgShown.toStringAsFixed(2)}',
            );
          },
        ),
        AppTheme.sizedBoxSml,

        // Historical Average Questions Shown Per Day Graph
        FutureBuilder<List<Map<String, dynamic>>>(
          future: historicalAverageQuestionsShownPerDayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final history = snapshot.data ?? [];
            final graphData = history.map((e) => {
              'date': e['record_date'] ?? '',
              'value': e['average_questions_shown_per_day'] ?? 0.0,
            }).toList();
            return StatLineGraph(
              data: graphData,
              title: 'Average Questions Shown Per Day Over Time',
              legendLabel: 'Avg Questions/Day',
              yAxisLabel: 'Avg Questions/Day',
              xAxisLabel: 'Date',
              lineColor: Colors.green,
              chartName: 'Average Questions Shown Per Day Over Time',
            );
          },
        ),
        AppTheme.sizedBoxLrg,
      ],
    );
  }
} 