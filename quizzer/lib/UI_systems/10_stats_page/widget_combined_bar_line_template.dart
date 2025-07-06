import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

/// Data model for a single day in the stacked bar chart
class CombinedBarLineData {
  final String date; // e.g. '2024-06-01'
  final int correct;
  final int incorrect;
  final int total; // Should be correct + incorrect, but can be passed for flexibility
  CombinedBarLineData({required this.date, required this.correct, required this.incorrect, required this.total});
}

class CombinedBarLineChart extends StatelessWidget {
  final List<CombinedBarLineData> data;
  final String chartName;
  final String xAxisLabel;
  final String yAxisLabel;
  final Color correctColor;
  final Color incorrectColor;

  const CombinedBarLineChart({
    super.key,
    required this.data,
    required this.chartName,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.correctColor = Colors.green,
    this.incorrectColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available.'));
    }
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
          height: 220,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barsSpace = 4.0 * constraints.maxWidth / 400;
                final barsWidth = 14.0 * constraints.maxWidth / 400;
                // Prepare bar groups: one bar per date, stacked (incorrect on bottom, correct on top)
                final barGroups = <BarChartGroupData>[];
                for (int i = 0; i < data.length; i++) {
                  final d = data[i];
                  barGroups.add(
                    BarChartGroupData(
                      x: i,
                      barsSpace: barsSpace,
                      barRods: [
                        BarChartRodData(
                          toY: (d.correct + d.incorrect).toDouble(),
                          rodStackItems: [
                            BarChartRodStackItem(0, d.incorrect.toDouble(), incorrectColor),
                            BarChartRodStackItem(d.incorrect.toDouble(), (d.correct + d.incorrect).toDouble(), correctColor),
                          ],
                          borderRadius: BorderRadius.zero,
                          width: barsWidth,
                        ),
                      ],
                    ),
                  );
                }
                // Prepare x axis labels (dates)
                final xLabels = data.map((d) => d.date.length >= 10 ? d.date.substring(5) : d.date).toList();
                final double yMax = data.map((d) => d.correct + d.incorrect).fold<double>(0, (prev, el) => el > prev ? el.toDouble() : prev);
                final double yMaxDisplay = yMax == 0 ? 1 : (yMax * 1.2);
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    barGroups: barGroups,
                    minY: 0,
                    maxY: yMaxDisplay,
                    groupsSpace: barsSpace,
                    barTouchData: const BarTouchData(enabled: true),
                    borderData: FlBorderData(show: true),
                    gridData: const FlGridData(show: true),
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
                          reservedSize: 32,
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
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  ),
                );
              },
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
                  const Text('Correct', style: ColorWheel.defaultText),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 16, color: incorrectColor),
                  const SizedBox(width: 4),
                  const Text('Incorrect', style: ColorWheel.defaultText),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
