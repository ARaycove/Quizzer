import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_graph_template.dart';
import 'package:quizzer/app_theme.dart';

class AverageDailyQuestionsLearnedStatWidget extends StatefulWidget {
  const AverageDailyQuestionsLearnedStatWidget({super.key});

  @override
  State<AverageDailyQuestionsLearnedStatWidget> createState() => _AverageDailyQuestionsLearnedStatWidgetState();
}

class _AverageDailyQuestionsLearnedStatWidgetState extends State<AverageDailyQuestionsLearnedStatWidget> {
  late Future<Map<String, dynamic>?> currentAverageDailyQuestionsLearnedFuture;
  late Future<List<Map<String, dynamic>>> historicalAverageDailyQuestionsLearnedFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentAverageDailyQuestionsLearnedFuture = session.getCurrentAverageDailyQuestionsLearnedStat();
    historicalAverageDailyQuestionsLearnedFuture = session.getHistoricalAverageDailyQuestionsLearnedStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Average Daily Questions Learned Stat
        FutureBuilder<Map<String, dynamic>?>(
          future: currentAverageDailyQuestionsLearnedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stat = snapshot.data;
            final double avgLearned = stat != null ? (stat['average_daily_questions_learned'] as double? ?? 0.0) : 0.0;
            return Text(
              'Current Average Daily Questions Learned: ${avgLearned.toStringAsFixed(2)}',
            );
          },
        ),
        AppTheme.sizedBoxSml,

        // Historical Average Daily Questions Learned Graph
        FutureBuilder<List<Map<String, dynamic>>>(
          future: historicalAverageDailyQuestionsLearnedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('No historical average daily questions learned data available.'));
            }
            final history = snapshot.data!;
            final graphData = history.map((e) => {
              'date': e['record_date'] ?? '',
              'value': e['average_daily_questions_learned'] ?? 0.0,
            }).toList();
            return StatLineGraph(
              data: graphData,
              title: 'Average Daily Questions Learned Over Time',
              legendLabel: 'Avg Questions Learned/Day',
              yAxisLabel: 'Avg Questions Learned/Day',
              xAxisLabel: 'Date',
              lineColor: Colors.purple,
              chartName: 'Average Daily Questions Learned Over Time',
            );
          },
        ),
        AppTheme.sizedBoxLrg,
      ],
    );
  }
} 