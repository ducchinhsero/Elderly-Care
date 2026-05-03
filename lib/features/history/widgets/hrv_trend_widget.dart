import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/history_model.dart';

/// Tab HRV - LineChart RMSSD + BarChart phân bố theo giờ
class HrvTrendWidget extends StatelessWidget {
  final HistoryModel? history;
  const HrvTrendWidget({super.key, this.history});

  @override
  Widget build(BuildContext context) {
    if (history == null || history!.isEmpty) {
      return Center(child: Text(AppStrings.noData, style: TextStyle(color: AppColors.textSecondary)));
    }

    final points = history!.points;
    final stats = history!.stats!;
    final firstTime = points.first.timestamp;
    final spots = points.asMap().entries.map((e) {
      final diff = e.value.timestamp.difference(firstTime).inMinutes.toDouble();
      return FlSpot(diff, e.value.rmssdMs);
    }).toList();

    // Hourly distribution
    final hourlyRmssd = <int, List<double>>{};
    for (final p in points) {
      hourlyRmssd.putIfAbsent(p.timestamp.hour, () => []).add(p.rmssdMs);
    }
    final hourlyAvg = hourlyRmssd.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RMSSD (ms)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)))),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(spots: spots, isCurved: true, curveSmoothness: 0.3, color: AppColors.primary, barWidth: 2,
                            dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.chartFill)),
                        ],
                        // Dashed line for normal threshold
                        extraLinesData: ExtraLinesData(horizontalLines: [
                          HorizontalLine(y: 20, color: AppColors.safe.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 5],
                            label: HorizontalLineLabel(show: true, alignment: Alignment.topRight,
                              style: TextStyle(fontSize: 10, color: AppColors.safe), labelResolver: (_) => 'Ngưỡng bình thường')),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Stats
          Row(
            children: [
              _StatCard(label: 'TB', value: stats.rmssdAvg.toStringAsFixed(1), unit: 'ms', color: AppColors.primary),
              const SizedBox(width: 8),
              _StatCard(label: 'Thấp nhất', value: stats.rmssdMin.toStringAsFixed(1), unit: 'ms', color: AppColors.alert),
              const SizedBox(width: 8),
              _StatCard(label: 'Cao nhất', value: stats.rmssdMax.toStringAsFixed(1), unit: 'ms', color: AppColors.safe),
            ],
          ),
          const SizedBox(height: 12),
          // Hourly bar chart
          if (hourlyAvg.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RMSSD theo giờ', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
                              getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(fontSize: 9, color: AppColors.textHint)))),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: hourlyAvg.entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(toY: e.value, color: AppColors.primary, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                          ])).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              Text(unit, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}
