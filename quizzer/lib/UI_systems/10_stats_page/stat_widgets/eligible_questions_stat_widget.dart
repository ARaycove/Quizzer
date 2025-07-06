import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import '../widget_graph_template.dart';

class EligibleQuestionsStatWidget extends StatefulWidget {
  const EligibleQuestionsStatWidget({super.key});

  @override
  State<EligibleQuestionsStatWidget> createState() => _EligibleQuestionsStatWidgetState();
}

class _EligibleQuestionsStatWidgetState extends State<EligibleQuestionsStatWidget> {
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
    return FutureBuilder<Map<String, dynamic>?>(
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
    );
  }
} 