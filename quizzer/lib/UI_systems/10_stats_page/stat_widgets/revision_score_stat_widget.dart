import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';
import '../widget_graph_template.dart';
import '../widget_bar_chart_template.dart';

// Custom StatLineGraph specifically for revision scores with sorted tooltips
class RevisionScoreLineGraph extends StatelessWidget {
  final List<StatLineSeries> seriesList;
  final String title;
  final String yAxisLabel;
  final String xAxisLabel;
  final bool showLegend;
  final String chartName;

  const RevisionScoreLineGraph({
    super.key,
    required this.seriesList,
    required this.title,
    required this.chartName,
    this.yAxisLabel = 'Value',
    this.xAxisLabel = 'Date',
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (seriesList.isEmpty || seriesList.every((s) => s.data.isEmpty)) {
      return const Center(child: Text('No data available'));
    }
    
    // Merge all dates from all series
    final allDates = <String>{};
    for (final s in seriesList) {
      allDates.addAll(s.data.map((e) => e['date'] as String));
    }
    final sortedDates = allDates.toList()..sort();
    
    // Map date to x index
    final dateToX = {for (var i = 0; i < sortedDates.length; i++) sortedDates[i]: i.toDouble()};
    
    // Prepare spots for each series
    final List<LineChartBarData> lines = [];
    double maxValue = 0;
    for (final s in seriesList) {
      final spots = <FlSpot>[];
      for (final e in s.data) {
        final date = e['date'] as String;
        final value = (e['value'] as num).toDouble();
        if (value > maxValue) maxValue = value;
        if (dateToX.containsKey(date)) {
          spots.add(FlSpot(dateToX[date]!, value));
        }
      }
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: s.lineColor,
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ));
    }
    
    // Prepare x axis labels (dates)
    final xLabels = sortedDates.map((dateStr) {
      if (dateStr.length >= 10) {
        return dateStr.substring(0, 10);
      }
      final tIndex = dateStr.indexOf('T');
      if (tIndex > 0) {
        return dateStr.substring(0, tIndex);
      }
      return dateStr;
    }).toList();
    
    final uniqueXLabels = xLabels.toSet().toList();
    final double yMax = maxValue == 0 ? 1 : (maxValue * 1.02);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: LineChart(
              LineChartData(
                lineBarsData: lines,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: ColorWheel.defaultText.copyWith(fontSize: 10),
                        );
                      },
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(yAxisLabel, style: ColorWheel.defaultText.copyWith(fontSize: 12)),
                    ),
                    axisNameSize: 24,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                        if (uniqueXLabels.length == 1) {
                          if (idx == 0) {
                            return Transform.rotate(
                              angle: -0.7,
                              child: Text(xLabels[0], style: ColorWheel.defaultText.copyWith(fontSize: 10)),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }
                        if (xLabels.length == 1) {
                          return Transform.rotate(
                            angle: -0.7,
                            child: Text(xLabels[0], style: ColorWheel.defaultText.copyWith(fontSize: 10)),
                          );
                        }
                        if (idx == 0 || idx == xLabels.length - 1) {
                          return Transform.rotate(
                            angle: -0.7,
                            child: Text(xLabels[idx], style: ColorWheel.defaultText.copyWith(fontSize: 10)),
                          );
                        }
                        if (xLabels.length > 2) {
                          int interval = (xLabels.length / 4).ceil();
                          if (interval > 0 && idx % interval == 0 && idx != 0 && idx != xLabels.length - 1) {
                            int shown = 2;
                            for (int i = 1; i < xLabels.length - 1; i++) {
                              if (i % interval == 0) shown++;
                            }
                            if (shown <= 5) {
                              return Transform.rotate(
                                angle: -0.7,
                                child: Text(xLabels[idx], style: ColorWheel.defaultText.copyWith(fontSize: 10)),
                              );
                            }
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 32,
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(xAxisLabel, style: ColorWheel.defaultText.copyWith(fontSize: 12)),
                    ),
                    axisNameSize: 24,
                  ),
                  topTitles: AxisTitles(
                    axisNameWidget: Text(
                      chartName,
                      style: ColorWheel.titleText.copyWith(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    axisNameSize: 32,
                    sideTitles: const SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                minY: 0,
                maxY: yMax,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      final sorted = touchedSpots.toList()
                        ..sort((a, b) {
                          int scoreA = 0;
                          int scoreB = 0;
                          if (seriesList[a.barIndex].legendLabel.contains('Score')) {
                            scoreA = int.tryParse(seriesList[a.barIndex].legendLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          }
                          if (seriesList[b.barIndex].legendLabel.contains('Score')) {
                            scoreB = int.tryParse(seriesList[b.barIndex].legendLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          }
                          return scoreA.compareTo(scoreB);
                        });
                      return sorted.map((spot) {
                        final series = seriesList[spot.barIndex];
                        const double shadowCircleOffset = 1.5;
                        const double shadowCircleOffsetNegative = -1.5;
                        const double blurRadius = 2;
                        return LineTooltipItem(
                          "",
                          const TextStyle(fontWeight: FontWeight.normal, height: 1.5),
                          children: [
                            TextSpan(
                              text: "\u25CF  ",
                              style: TextStyle(
                                fontSize: 16,
                                color: series.lineColor, 
                                shadows: const [
                                  Shadow(offset: Offset(shadowCircleOffsetNegative, shadowCircleOffset), blurRadius: blurRadius, color: Colors.white),
                                  Shadow(offset: Offset(shadowCircleOffset, shadowCircleOffsetNegative), blurRadius: blurRadius, color: Colors.white),
                                  Shadow(offset: Offset(shadowCircleOffset, shadowCircleOffset), blurRadius: blurRadius, color: Colors.white),
                                  Shadow(offset: Offset(shadowCircleOffsetNegative, shadowCircleOffsetNegative), blurRadius: blurRadius, color: Colors.white),
                                ],
                              ),
                            ),
                            TextSpan(
                              text: "${series.legendLabel}: ${spot.y.toInt()}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showLegend)
          Positioned(
            right: 0,
            top: 0,
            child: Wrap(
              spacing: 16,
              children: [
                for (final s in seriesList)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 16, height: 4, color: s.lineColor),
                      const SizedBox(width: 8),
                      Text(
                        s.legendLabel,
                        style: ColorWheel.defaultText.copyWith(
                          color: ColorWheel.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class RevisionScoreStatWidget extends StatefulWidget {
  const RevisionScoreStatWidget({super.key});

  @override
  State<RevisionScoreStatWidget> createState() => _RevisionScoreStatWidgetState();
}

class _RevisionScoreStatWidgetState extends State<RevisionScoreStatWidget> {
  late Future<List<Map<String, dynamic>>> currentRevisionStreakStatsFuture;
  late Future<List<Map<String, dynamic>>> historicalRevisionStreakStatsFuture;

  @override
  void initState() {
    super.initState();
    final session = SessionManager();
    currentRevisionStreakStatsFuture = session.getCurrentRevisionStreakSumStats();
    historicalRevisionStreakStatsFuture = session.getHistoricalRevisionStreakSumStats();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                const Text(
                  'Current Question Distribution by Revision Score',
                  style: ColorWheel.titleText,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                StatBarChart(
                  data: barChartData,
                  chartName: '', // Title handled above
                  xAxisLabel: 'Revision Score',
                  yAxisLabel: 'Number of Questions',
                  barColor: Colors.teal,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

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

            return RevisionScoreLineGraph(
              title: 'Historical Question Count by Revision Score',
              seriesList: seriesList,
              chartName: 'Historical Question Count by Revision Score',
              xAxisLabel: 'Date',
              yAxisLabel: 'Number of Questions',
              showLegend: true,
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
} 