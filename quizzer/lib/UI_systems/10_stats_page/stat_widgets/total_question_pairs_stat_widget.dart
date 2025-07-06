import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import '../widget_graph_template.dart';

class TotalQuestionPairsStatWidget extends StatefulWidget {
  const TotalQuestionPairsStatWidget({super.key});

  @override
  State<TotalQuestionPairsStatWidget> createState() => _TotalQuestionPairsStatWidgetState();
}

class _TotalQuestionPairsStatWidgetState extends State<TotalQuestionPairsStatWidget> {
  late Future<int> currentTotalUserQuestionAnswerPairsFuture;
  late Future<List<Map<String, dynamic>>> historicalTotalUserQuestionAnswerPairsFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentTotalUserQuestionAnswerPairsFuture = session.getCurrentTotalUserQuestionAnswerPairsCount();
    historicalTotalUserQuestionAnswerPairsFuture = session.getHistoricalTotalUserQuestionAnswerPairsStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Total User Question Answer Pairs Stat
        FutureBuilder<int>(
          future: currentTotalUserQuestionAnswerPairsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final int total = snapshot.data ?? 0;
            return Text(
              'Total User Question Answer Pairs: $total',
              style: ColorWheel.titleText,
            );
          },
        ),
        const SizedBox(height: 8),

        // Historical Total User Question Answer Pairs Line Graph
        FutureBuilder<List<Map<String, dynamic>>>(
          future: historicalTotalUserQuestionAnswerPairsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('No historical total user question answer pairs data available.', style: ColorWheel.defaultText));
            }
            final history = snapshot.data!;
            final graphData = history.map((e) => {
              'date': e['record_date'] ?? '',
              'value': (e['total_question_answer_pairs'] as int?)?.toDouble() ?? 0.0,
            }).toList();
            return StatLineGraph(
              data: graphData,
              title: 'Total User Question Answer Pairs Over Time',
              legendLabel: 'Total User Questions',
              yAxisLabel: 'Total User Questions',
              xAxisLabel: 'Date',
              lineColor: Colors.deepPurple,
              chartName: 'Total User Question Answer Pairs Over Time',
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
} 