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






import 'package:flutter/material.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'widget_graph_template.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';
import 'widget_bar_chart_template.dart';
import 'widget_combined_bar_line_template.dart';

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
  late Future<List<Map<String, dynamic>>> currentRevisionStreakStatsFuture;
  late Future<List<Map<String, dynamic>>> historicalRevisionStreakStatsFuture;
  late Future<int> currentTotalUserQuestionAnswerPairsFuture;
  late Future<List<Map<String, dynamic>>> historicalTotalUserQuestionAnswerPairsFuture;
  late Future<Map<String, dynamic>?> currentAverageQuestionsShownPerDayFuture;
  late Future<List<Map<String, dynamic>>> historicalAverageQuestionsShownPerDayFuture;
  late Future<int> currentTotalQuestionsAnsweredFuture;
  late Future<List<Map<String, dynamic>>> historicalTotalQuestionsAnsweredFuture;
  late Future<List<Map<String, dynamic>>> historicalDailyQuestionsAnsweredFuture;
  late Future<Map<String, dynamic>?> currentAverageDailyQuestionsLearnedFuture;
  late Future<List<Map<String, dynamic>>> historicalAverageDailyQuestionsLearnedFuture;
  late Future<Map<String, dynamic>?> currentDaysLeftUntilQuestionsExhaustFuture;
  late Future<List<Map<String, dynamic>>> historicalDaysLeftUntilQuestionsExhaustFuture;

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
    currentRevisionStreakStatsFuture = session.getCurrentRevisionStreakSumStats();
    historicalRevisionStreakStatsFuture = session.getHistoricalRevisionStreakSumStats();
    currentTotalUserQuestionAnswerPairsFuture = session.getCurrentTotalUserQuestionAnswerPairsCount();
    historicalTotalUserQuestionAnswerPairsFuture = session.getHistoricalTotalUserQuestionAnswerPairsStats();
    currentAverageQuestionsShownPerDayFuture = session.getCurrentAverageQuestionsShownPerDayStat();
    historicalAverageQuestionsShownPerDayFuture = session.getHistoricalAverageQuestionsShownPerDayStats();
    currentTotalQuestionsAnsweredFuture = session.getCurrentTotalQuestionsAnsweredCount();
    historicalTotalQuestionsAnsweredFuture = session.getHistoricalTotalQuestionsAnsweredStats();
    historicalDailyQuestionsAnsweredFuture = session.getHistoricalDailyQuestionsAnsweredStats();
    currentAverageDailyQuestionsLearnedFuture = session.getCurrentAverageDailyQuestionsLearnedStat();
    historicalAverageDailyQuestionsLearnedFuture = session.getHistoricalAverageDailyQuestionsLearnedStats();
    currentDaysLeftUntilQuestionsExhaustFuture = session.getCurrentDaysLeftUntilQuestionsExhaustStat();
    historicalDaysLeftUntilQuestionsExhaustFuture = session.getHistoricalDaysLeftUntilQuestionsExhaustStats();
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current In Circulation Questions: $currentInCirc',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
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
            // Current Revision Streak Stats Bar Chart
            FutureBuilder<List<Map<String, dynamic>>>(
              future: currentRevisionStreakStatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No current revision streak data available.', style: ColorWheel.defaultText));
                }
                final stats = snapshot.data!;
                // Transform data for the bar chart
                final barChartData = stats.map((stat) {
                  return {
                    'x_label': 'Score ${stat['revision_streak_score']}',
                    'y_value': (stat['question_count'] as int).toDouble(),
                  };
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     StatBarChart(
                      data: barChartData,
                      chartName: 'Current Question Distribution by Revision Score',
                      xAxisLabel: 'Revision Score',
                      yAxisLabel: 'Number of Questions',
                      barColor: Colors.teal, // Example color
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Historical Revision Streak Stats Line Graph
            FutureBuilder<List<Map<String, dynamic>>>(
              future: historicalRevisionStreakStatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No historical revision streak data available.', style: ColorWheel.defaultText));
                }
                final history = snapshot.data!;
                
                // Group data by revision_streak_score, then by date
                Map<int, List<Map<String, dynamic>>> groupedByStreak = {};
                for (var record in history) {
                  int streak = record['revision_streak_score'] as int;
                  if (!groupedByStreak.containsKey(streak)) {
                    groupedByStreak[streak] = [];
                  }
                  groupedByStreak[streak]!.add({
                    'date': record['record_date'] ?? '',
                    'value': (record['question_count'] as int).toDouble(),
                  });
                }

                // Sort each streak's data by date
                groupedByStreak.forEach((streak, records) {
                  records.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
                });

                List<StatLineSeries> seriesList = [];
                // Define a list of colors for different streaks
                List<Color> streakColors = [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow.shade700,
                  Colors.lightGreen,
                  Colors.green,
                  Colors.teal,
                  Colors.cyan,
                  Colors.lightBlue,
                  Colors.blue,
                  Colors.indigo,
                  Colors.purple,
                  Colors.pink,
                  // Add more colors if you expect more than 12 unique streak scores often
                ];

                int colorIndex = 0;
                final streakEntries = groupedByStreak.entries.toList();
                streakEntries.sort((a, b) => a.key.compareTo(b.key)); // Sort streaks by score for consistent legend order
                for (final entry in streakEntries) {
                  seriesList.add(StatLineSeries(
                    legendLabel: 'Score ${entry.key}',
                    data: entry.value,
                    lineColor: streakColors[colorIndex % streakColors.length],
                  ));
                  colorIndex++;
                }

                if (seriesList.isEmpty) {
                   return const Center(child: Text('Not enough data to display historical streak graph.', style: ColorWheel.defaultText));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatLineGraph.multi(
                      title: 'Historical Question Count by Revision Score',
                      seriesList: seriesList,
                      chartName: 'Historical Question Count by Revision Score',
                      xAxisLabel: 'Date',
                      yAxisLabel: 'Number of Questions',
                      showLegend: true,
                    ),
                     const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Total User Question Answer Pairs Stat
            FutureBuilder<int>(
              future: currentTotalUserQuestionAnswerPairsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final int total = snapshot.data ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total User Question Answer Pairs: $total',
                      style: ColorWheel.titleText,
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),

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
            // Average Questions Shown Per Day Stat (text only)
            FutureBuilder<Map<String, dynamic>?>(
              future: currentAverageQuestionsShownPerDayFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stat = snapshot.data;
                final double avgShown = stat != null ? (stat['average_questions_shown_per_day'] as double? ?? 0.0) : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Average Questions Shown Per Day: ${avgShown.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            // Average Questions Shown Per Day Graph
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
            // Total Questions Answered Stat
            FutureBuilder<int>(
              future: currentTotalQuestionsAnsweredFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final int total = snapshot.data ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Questions Answered: $total',
                      style: ColorWheel.titleText,
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),

            // Daily Questions Answered Stat
            FutureBuilder<List<Map<String, dynamic>>>(
              future: historicalDailyQuestionsAnsweredFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(child: Text('No daily questions answered data available.', style: ColorWheel.defaultText));
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
                      style: ColorWheel.titleText,
                    ),
                    const SizedBox(height: 8),
                    CombinedBarLineChart(
                      data: chartData,
                      chartName: 'Daily Questions Answered (Correct/Incorrect/Total)',
                      xAxisLabel: 'Date',
                      yAxisLabel: 'Questions',
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Historical Total Questions Answered Combined Chart
            FutureBuilder<List<Map<String, dynamic>>>(
              future: historicalTotalQuestionsAnsweredFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(child: Text('No historical total questions answered data available.', style: ColorWheel.defaultText));
                }
                final chartData = history.map((e) => CombinedBarLineData(
                  date: e['record_date'] ?? '',
                  correct: e['correct_questions_answered'] ?? 0,
                  incorrect: e['incorrect_questions_answered'] ?? 0,
                  total: e['total_questions_answered'] ?? 0,
                )).toList();
                return CombinedBarLineChart(
                  data: chartData,
                  chartName: 'Total Questions Answered Over Time (Correct/Incorrect/Total)',
                  xAxisLabel: 'Date',
                  yAxisLabel: 'Total',
                );
              },
            ),

            // Average Daily Questions Learned Stat (text only)
            FutureBuilder<Map<String, dynamic>?>(
              future: currentAverageDailyQuestionsLearnedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stat = snapshot.data;
                final double avgLearned = stat != null ? (stat['average_daily_questions_learned'] as double? ?? 0.0) : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Average Daily Questions Learned: ${avgLearned.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            // Average Daily Questions Learned Graph
            FutureBuilder<List<Map<String, dynamic>>>(
              future: historicalAverageDailyQuestionsLearnedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
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
            // Days Left Until Questions Exhaust Stat (text only)
            FutureBuilder<Map<String, dynamic>?>(
              future: currentDaysLeftUntilQuestionsExhaustFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stat = snapshot.data;
                final double daysLeft = stat != null ? (stat['days_left_until_questions_exhaust'] as double? ?? 0.0) : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Days Left Until Questions Exhaust: ${daysLeft.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            // Days Left Until Questions Exhaust Graph
            FutureBuilder<List<Map<String, dynamic>>>(
              future: historicalDaysLeftUntilQuestionsExhaustFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
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