import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quizzer/app_theme.dart';

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
        Center(
          child: Text(
            chartName,
            textAlign: TextAlign.center,
          ),
        ),
        AppTheme.sizedBoxSml,
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barsSpace = 4.0 * constraints.maxWidth / 400;
              // CHANGING WIDTH DOES NOT CHANGE THE SHAPE OF THE BARS 
              // FUCKING DUMB ASS IDIOT
              final barsWidth = 8.0 * constraints.maxWidth / 400; // Reasonable width for rectangular bars
              // Prepare bar groups: one bar per date, stacked (incorrect on bottom, correct on top)
              final barGroups = <BarChartGroupData>[];
              for (int i = 0; i < data.length; i++) {
                final d = data[i];
                final total = d.correct + d.incorrect;
                
                // Only create bars if there's actual data
                if (total > 0) {
                  barGroups.add(
                    BarChartGroupData(
                      x: i,
                      barsSpace: barsSpace,
                      barRods: [
                        BarChartRodData(
                          toY: total.toDouble(),
                          rodStackItems: [
                            BarChartRodStackItem(0, d.incorrect.toDouble(), incorrectColor),
                            BarChartRodStackItem(d.incorrect.toDouble(), total.toDouble(), correctColor),
                          ],
                          width: barsWidth,
                          borderRadius: BorderRadius.zero, // Make bars rectangular instead of circular
                        ),
                      ],
                    ),
                  );
                } else {
                  // Add empty bar group to maintain spacing - NO VISUAL BAR
                  barGroups.add(
                    BarChartGroupData(
                      x: i,
                      barsSpace: barsSpace,
                      barRods: [], // Empty array means no visual bar
                    ),
                  );
                }
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
                          return Text(value.toInt().toString());
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
                              child: Text(xLabels[idx]),
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
        AppTheme.sizedBoxSml,
        Center(
          child: Text(xAxisLabel),
        ),
        AppTheme.sizedBoxSml,
        Wrap(
          spacing: 16,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 16, color: correctColor),
                AppTheme.sizedBoxSml,
                const Text('Correct'),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 16, height: 16, color: incorrectColor),
                AppTheme.sizedBoxSml,
                const Text('Incorrect'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
