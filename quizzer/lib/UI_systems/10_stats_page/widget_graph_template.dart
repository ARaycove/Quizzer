import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class StatLineSeries {
  final String legendLabel;
  final Color lineColor;
  final List<Map<String, dynamic>> data; // Each map: { 'date': String, 'value': int/double }
  StatLineSeries({
    required this.legendLabel,
    required this.lineColor,
    required this.data,
  });
}

class StatLineGraph extends StatelessWidget {
  final List<StatLineSeries> seriesList;
  final String title;
  final String yAxisLabel;
  final String xAxisLabel;
  final bool showLegend;
  final String chartName; // Required, user-facing

  // Backward compatibility: allow single-series constructor
  StatLineGraph({
    super.key,
    required List<Map<String, dynamic>> data,
    required String legendLabel,
    required this.title,
    required this.chartName,
    this.yAxisLabel = 'Value',
    this.xAxisLabel = 'Date',
    Color lineColor = Colors.blue,
    this.showLegend = true,
  }) : seriesList = [
    StatLineSeries(legendLabel: legendLabel, lineColor: lineColor, data: data),
  ];

  // Multi-series constructor
  StatLineGraph.multi({
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
        Text(title, style: Theme.of(context).textTheme.titleLarge),
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
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      },
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(yAxisLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                              child: Text(xLabels[0], style: const TextStyle(fontSize: 10, color: Colors.white)),
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }
                        if (xLabels.length == 1) {
                          return Transform.rotate(
                            angle: -0.7,
                            child: Text(xLabels[0], style: const TextStyle(fontSize: 10, color: Colors.white)),
                          );
                        }
                        if (idx == 0 || idx == xLabels.length - 1) {
                          return Transform.rotate(
                            angle: -0.7,
                            child: Text(xLabels[idx], style: const TextStyle(fontSize: 10, color: Colors.white)),
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
                                child: Text(xLabels[idx], style: const TextStyle(fontSize: 10, color: Colors.white)),
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
                      child: Text(xAxisLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    axisNameSize: 24,
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                minY: 0,
                maxY: yMax,
              ),
            ),
          ),
        ),
        if (showLegend)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColorWheel.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                Text(chartName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
      ],
    );
  }
}
