import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_combined_bar_line_template.dart';
import 'package:quizzer/app_theme.dart';

class TotalQuestionsAnsweredStatWidget extends StatefulWidget {
  const TotalQuestionsAnsweredStatWidget({super.key});

  @override
  State<TotalQuestionsAnsweredStatWidget> createState() => _TotalQuestionsAnsweredStatWidgetState();
}

class _TotalQuestionsAnsweredStatWidgetState extends State<TotalQuestionsAnsweredStatWidget> {
  late Future<int> currentTotalQuestionsAnsweredFuture;
  late Future<List<Map<String, dynamic>>> historicalTotalQuestionsAnsweredFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentTotalQuestionsAnsweredFuture = session.getCurrentTotalQuestionsAnsweredCount();
    historicalTotalQuestionsAnsweredFuture = session.getHistoricalTotalQuestionsAnsweredStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Total Questions Answered Stat
        FutureBuilder<int>(
          future: currentTotalQuestionsAnsweredFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final int total = snapshot.data ?? 0;
            return Text(
              'Total Questions Answered: $total',
            );
          },
        ),
        AppTheme.sizedBoxSml,

        // Historical Total Questions Answered Combined Bar/Line Chart
        FutureBuilder<List<Map<String, dynamic>>>(
          future: historicalTotalQuestionsAnsweredFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('No historical total questions answered data available.'));
            }
            final history = snapshot.data!;
            final chartData = history.map((e) => CombinedBarLineData(
              date: e['record_date'] ?? '',
              correct: e['correct_questions_answered'] ?? 0,
              incorrect: e['incorrect_questions_answered'] ?? 0,
              total: e['total_questions_answered'] ?? 0,
            )).toList();
            return CombinedBarLineChart(
              data: chartData,
              chartName: 'Total Questions Answered Over Time',
              xAxisLabel: 'Date',
              yAxisLabel: 'Questions',
            );
          },
        ),
        AppTheme.sizedBoxLrg,
      ],
    );
  }
} 