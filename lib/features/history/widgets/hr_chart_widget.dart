import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/history_model.dart';

/// Tab Nhịp tim - LineChart HR theo thời gian
class HrChartWidget extends StatelessWidget {
  final HistoryModel? history;
  const HrChartWidget({super.key, this.history});

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
      return FlSpot(diff, e.value.hrBpm);
    }).toList();

    // Alert points (red dots)
    final alertSpots = points.asMap().entries
        .where((e) => e.value.hasAlert)
        .map((e) {
          final diff = e.value.timestamp.difference(firstTime).inMinutes.toDouble();
          return FlSpot(diff, e.value.hrBpm);
        }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.heartRate, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20,
                          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.chartGrid.withValues(alpha: 0.3), strokeWidth: 1)),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 20,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)))),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                          HorizontalRangeAnnotation(y1: 60, y2: 100, color: AppColors.chartNormalZone),
                        ]),
                        lineBarsData: [
                          LineChartBarData(spots: spots, isCurved: true, curveSmoothness: 0.2, color: AppColors.chartLine, barWidth: 2, dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: AppColors.chartFill)),
                          // Alert dots
                          if (alertSpots.isNotEmpty)
                            LineChartBarData(spots: alertSpots, isCurved: false, color: Colors.transparent, barWidth: 0,
                              dotData: FlDotData(show: true, getDotPainter: (s, _, __, ___) => FlDotCirclePainter(radius: 4, color: AppColors.critical, strokeColor: Colors.white, strokeWidth: 1))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Stats cards
          Row(
            children: [
              _StatCard(label: AppStrings.avgHR, value: '${stats.hrAvg.toStringAsFixed(0)}', unit: 'BPM', color: AppColors.primary),
              const SizedBox(width: 8),
              _StatCard(label: AppStrings.minHR, value: '${stats.hrMin.toStringAsFixed(0)}', unit: 'BPM', color: AppColors.safe),
              const SizedBox(width: 8),
              _StatCard(label: AppStrings.maxHR, value: '${stats.hrMax.toStringAsFixed(0)}', unit: 'BPM', color: AppColors.alert),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.safe),
              title: Text('${stats.normalPercent.toStringAsFixed(1)}% ${AppStrings.normalPercent}'),
              subtitle: Text('${AppStrings.normalRange}: 60-100 BPM', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
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
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(unit, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}
