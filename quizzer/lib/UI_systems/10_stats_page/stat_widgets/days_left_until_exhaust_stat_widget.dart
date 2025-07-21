import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_graph_template.dart';
import 'package:quizzer/app_theme.dart';

class DaysLeftUntilExhaustStatWidget extends StatefulWidget {
  const DaysLeftUntilExhaustStatWidget({super.key});

  @override
  State<DaysLeftUntilExhaustStatWidget> createState() => _DaysLeftUntilExhaustStatWidgetState();
}

class _DaysLeftUntilExhaustStatWidgetState extends State<DaysLeftUntilExhaustStatWidget> {
  late Future<Map<String, dynamic>?> currentDaysLeftUntilQuestionsExhaustFuture;
  late Future<List<Map<String, dynamic>>> historicalDaysLeftUntilQuestionsExhaustFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentDaysLeftUntilQuestionsExhaustFuture = session.getCurrentDaysLeftUntilQuestionsExhaustStat();
    historicalDaysLeftUntilQuestionsExhaustFuture = session.getHistoricalDaysLeftUntilQuestionsExhaustStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Days Left Until Questions Exhaust Stat
        FutureBuilder<Map<String, dynamic>?>(
          future: currentDaysLeftUntilQuestionsExhaustFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final stat = snapshot.data;
            final double daysLeft = stat != null ? (stat['days_left_until_questions_exhaust'] as double? ?? 0.0) : 0.0;
            return Text(
              'Current Days Left Until Questions Exhaust: ${daysLeft.toStringAsFixed(2)}',
            );
          },
        ),
        AppTheme.sizedBoxSml,

        // Historical Days Left Until Questions Exhaust Graph
        FutureBuilder<List<Map<String, dynamic>>>(
          future: historicalDaysLeftUntilQuestionsExhaustFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('No historical days left until questions exhaust data available.'));
            }
            final history = snapshot.data!;
            final graphData = history.map((e) => {
              'date': e['record_date'] ?? '',
              'value': e['days_left_until_questions_exhaust'] ?? 0.0,
            }).toList();
            return StatLineGraph(
              data: graphData,
              title: 'Days Left Until Questions Exhaust Over Time',
              legendLabel: 'Days Left',
              yAxisLabel: 'Days Left',
              xAxisLabel: 'Date',
              lineColor: Colors.red,
              chartName: 'Days Left Until Questions Exhaust Over Time',
            );
          },
        ),
        AppTheme.sizedBoxLrg,
      ],
    );
  }
} 