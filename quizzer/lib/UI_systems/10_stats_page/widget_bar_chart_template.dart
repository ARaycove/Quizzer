import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/color_wheel.dart';

class StatBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data; // Expects {'x_label': String, 'y_value': double}
  final String chartName;
  final String xAxisLabel;
  final String yAxisLabel;
  final Color barColor;

  const StatBarChart({
    super.key,
    required this.data,
    required this.chartName,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.barColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available for $chartName',
          style: ColorWheel.defaultText,
        ),
      );
    }

    // Determine the maximum y-value for scaling the y-axis
    double maxY = 0;
    for (var item in data) {
      if (item['y_value'] > maxY) {
        maxY = item['y_value'] as double;
      }
    }
    // Add some padding to the max Y, ensure it's at least a small value if all data is 0
    maxY = maxY == 0 ? 10 : (maxY * 1.2);

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      barGroups.add(
        BarChartGroupData(
          x: i, // Integer index for x
          barRods: [
            BarChartRodData(
              toY: item['y_value'] as double,
              color: barColor,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 60, left: 12, top: 0, bottom: 0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = data[group.x];
                      return BarTooltipItem(
                        '${item['x_label']}: ${rod.toY.toStringAsFixed(1)}',
                        ColorWheel.defaultText.copyWith(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(
                    sideTitles: const SideTitles(showTitles: false),
                    axisNameWidget: chartName.isNotEmpty ? Text(chartName, style: ColorWheel.titleText.copyWith(color: Colors.white)) : null,
                    axisNameSize: 40,
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              data[index]['x_label'] as String,
                              style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(xAxisLabel, style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 12)),
                    ),
                     axisNameSize: 30,
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                         if (value % 1 == 0) { // Only show integer values
                            return Text(value.toInt().toString(), style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 10));
                         }
                         return const Text('');
                      },
                    ),
                    axisNameWidget: Text(yAxisLabel, style: ColorWheel.secondaryTextStyle.copyWith(fontSize: 12)),
                    axisNameSize: 40,
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: ColorWheel.primaryBorder, width: 1),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: ColorWheel.primaryBorder.withValues(alpha: 0.5),
                      strokeWidth: 0.5,
                    );
                  },
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
