import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_combined_bar_line_template.dart';
import 'package:quizzer/app_theme.dart';

class DailyQuestionsAnsweredStatWidget extends StatefulWidget {
  const DailyQuestionsAnsweredStatWidget({super.key});

  @override
  State<DailyQuestionsAnsweredStatWidget> createState() => _DailyQuestionsAnsweredStatWidgetState();
}

class _DailyQuestionsAnsweredStatWidgetState extends State<DailyQuestionsAnsweredStatWidget> {
  late Future<List<Map<String, dynamic>>> historicalDailyQuestionsAnsweredFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    historicalDailyQuestionsAnsweredFuture = session.getHistoricalDailyQuestionsAnsweredStats();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: historicalDailyQuestionsAnsweredFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return const Center(child: Text('No daily questions answered data available.'));
        }
        final latest = history.last;
        final int correct = latest['correct_questions_answered'] ?? 0;
        final int incorrect = latest['incorrect_questions_answered'] ?? 0;
        final int total = latest['daily_questions_answered'] ?? 0;
        final chartData = history.map((e) => CombinedBarLineData(
          date: e['record_date'] ?? '',
          correct: e['correct_questions_answered'] ?? 0,
          incorrect: e['incorrect_questions_answered'] ?? 0,
          total: e['daily_questions_answered'] ?? 0,
        )).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today: $total answered (Correct: $correct, Incorrect: $incorrect)',
            ),
            AppTheme.sizedBoxSml,
            CombinedBarLineChart(
              data: chartData,
              chartName: 'Daily Questions Answered (Correct/Incorrect/Total)',
              xAxisLabel: 'Date',
              yAxisLabel: 'Questions',
            ),
            AppTheme.sizedBoxLrg,
          ],
        );
      },
    );
  }
} 