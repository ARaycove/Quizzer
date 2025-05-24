import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatLineGraph extends StatelessWidget {
  final List<Map<String, dynamic>> data; // Each map: { 'date': String, 'value': int/double }
  final String title;
  final String legendLabel;

  const StatLineGraph({
    super.key,
    required this.data,
    required this.title,
    required this.legendLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    // Sort data by date
    final sortedData = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) => a['date'].compareTo(b['date']));
    // Prepare spots for the line chart
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedData.length; i++) {
      final value = (sortedData[i]['value'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
    }
    // Prepare x axis labels (dates)
    final xLabels = sortedData.map((e) {
      final dateStr = e['date'] as String;
      // Format to yyyy-MM-dd for clarity (manual, no intl)
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
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        // Show integer ticks only
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      },
                    ),
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Text('Eligible Questions', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    axisNameSize: 24,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                        // If all xLabels are the same, only show the label at the data point's index (usually idx == 0)
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
                        // For more than 2 points, show at most 5 labels (first, last, and 3 spaced)
                        if (xLabels.length > 2) {
                          int interval = (xLabels.length / 4).ceil();
                          if (interval > 0 && idx % interval == 0 && idx != 0 && idx != xLabels.length - 1) {
                            // Only show up to 5 labels
                            int shown = 2; // first and last
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
                    axisNameWidget: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Date', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    axisNameSize: 24,
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true),
                minY: 0,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Container(width: 16, height: 4, color: Colors.blue),
              const SizedBox(width: 8),
              Text(legendLabel, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
