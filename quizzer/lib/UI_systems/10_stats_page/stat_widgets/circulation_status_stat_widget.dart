import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/10_stats_page/widget_graph_template.dart';
import 'package:quizzer/app_theme.dart';

class CirculationStatusStatWidget extends StatefulWidget {
  const CirculationStatusStatWidget({super.key});

  @override
  State<CirculationStatusStatWidget> createState() => _CirculationStatusStatWidgetState();
}

class _CirculationStatusStatWidgetState extends State<CirculationStatusStatWidget> {
  late Future<List<Map<String, dynamic>>> nonCirculatingQuestionsHistoryFuture;
  late Future<List<Map<String, dynamic>>> inCirculationQuestionsHistoryFuture;
  late Future<Map<String, dynamic>?> currentNonCirculatingQuestionsFuture;
  late Future<Map<String, dynamic>?> currentInCirculationQuestionsFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    nonCirculatingQuestionsHistoryFuture = session.getNonCirculatingQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    inCirculationQuestionsHistoryFuture = session.getInCirculationQuestionsStats(getAll: true).then((data) => List<Map<String, dynamic>>.from(data));
    currentNonCirculatingQuestionsFuture = session.getNonCirculatingQuestionsStats().then((value) => value as Map<String, dynamic>?);
    currentInCirculationQuestionsFuture = session.getInCirculationQuestionsStats().then((value) => value as Map<String, dynamic>?);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
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
                ),
                AppTheme.sizedBoxSml,
                Text(
                  'Current In Circulation Questions: $currentInCirc',
                ),
                AppTheme.sizedBoxSml,
                StatLineGraph.multi(
                  seriesList: [nonCircSeries, inCircSeries],
                  title: 'Circulation Status Over Time',
                  chartName: 'Circulation Status Over Time',
                  yAxisLabel: 'Questions',
                  xAxisLabel: 'Date',
                  showLegend: true,
                ),
                AppTheme.sizedBoxLrg,
              ],
            );
          },
        );
      },
    );
  }
} 