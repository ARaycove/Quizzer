import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

/// Data model for a single day in the combined chart
class CombinedBarLineData {
  final String date; // e.g. '2024-06-01'
  final int correct;
  final int incorrect;
  final int total; // Should be correct + incorrect, but can be passed for flexibility
  CombinedBarLineData({required this.date, required this.correct, required this.incorrect, required this.total});
}

/// Generic widget for a combined stacked bar chart (correct/incorrect) and a line graph overlay (cumulative total)
class CombinedBarLineChart extends StatelessWidget {
  final List<CombinedBarLineData> data;
  final String chartName;
  final String xAxisLabel;
  final String yAxisLabel;
  final Color correctColor;
  final Color incorrectColor;
  final Color lineColor;

  const CombinedBarLineChart({
    Key? key,
    required this.data,
    required this.chartName,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.correctColor = Colors.green,
    this.incorrectColor = Colors.red,
    this.lineColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available.'));
    }
    // Prepare bar and line data
    final barGroups = <BarChartGroupData>[];
    final lineSpots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (d.correct + d.incorrect).toDouble(),
              width: 14,
              borderRadius: BorderRadius.zero,
              rodStackItems: [
                BarChartRodStackItem(
                  0,
                  d.incorrect.toDouble(),
                  incorrectColor,
                ),
                BarChartRodStackItem(
                  d.incorrect.toDouble(),
                  (d.incorrect + d.correct).toDouble(),
                  correctColor,
                ),
              ],
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
      lineSpots.add(FlSpot(i.toDouble(), d.total.toDouble()));
    }
    // Prepare x axis labels (dates)
    final xLabels = data.map((d) => d.date.length >= 10 ? d.date.substring(5) : d.date).toList();
    final double yMax = data.map((d) => d.total).fold<double>(0, (prev, el) => el > prev ? el.toDouble() : prev);
    final double yMaxDisplay = yMax == 0 ? 1 : (yMax * 1.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Center(
            child: Text(
              chartName,
              style: ColorWheel.titleText.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-axis label
                RotatedBox(
                  quarterTurns: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      yAxisLabel,
                      style: ColorWheel.defaultText.copyWith(fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      BarChart(
                        BarChartData(
                          barGroups: barGroups,
                          minY: 0,
                          maxY: yMaxDisplay,
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
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < xLabels.length) {
                                    return Transform.rotate(
                                      angle: -0.7,
                                      child: Text(xLabels[idx], style: ColorWheel.defaultText.copyWith(fontSize: 10)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 32,
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: true),
                          barTouchData: BarTouchData(enabled: true),
                        ),
                      ),
                      LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: lineSpots,
                              isCurved: false,
                              color: lineColor,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                            ),
                          ],
                          titlesData: FlTitlesData(show: false),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(enabled: false),
                          minX: 0,
                          maxX: (data.length - 1).toDouble(),
                          minY: 0,
                          maxY: yMaxDisplay,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // X-axis label
        Padding(
          padding: const EdgeInsets.only(top: 4.0, left: 32.0),
          child: Center(
            child: Text(
              xAxisLabel,
              style: ColorWheel.defaultText.copyWith(fontSize: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 16, color: correctColor),
                  const SizedBox(width: 4),
                  Text('Correct', style: ColorWheel.defaultText),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 16, color: incorrectColor),
                  const SizedBox(width: 4),
                  Text('Incorrect', style: ColorWheel.defaultText),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 2, color: lineColor),
                  const SizedBox(width: 4),
                  Text('Total', style: ColorWheel.defaultText),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
