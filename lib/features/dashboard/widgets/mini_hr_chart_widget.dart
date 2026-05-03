import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vitals_model.dart';

/// Mini chart HR 30 phút gần nhất
class MiniHrChartWidget extends StatelessWidget {
  final List<VitalsModel> dataPoints;

  const MiniHrChartWidget({super.key, required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return Center(
        child: Text('Chưa có dữ liệu', style: TextStyle(color: AppColors.textHint)),
      );
    }

    final spots = <FlSpot>[];
    final firstTime = dataPoints.first.timestamp;

    for (int i = 0; i < dataPoints.length; i++) {
      final diff = dataPoints[i].timestamp.difference(firstTime).inSeconds.toDouble();
      spots.add(FlSpot(diff, dataPoints[i].hrBpm));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.chartGrid.withOpacity(0.3), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 35, interval: 20,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minY.clamp(30, 200),
        maxY: maxY.clamp(40, 220),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.chartLine,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(show: spots.length < 20),
            belowBarData: BarAreaData(show: true, color: AppColors.chartFill),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) =>
              LineTooltipItem('${s.y.toStringAsFixed(0)} BPM', const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ).toList(),
          ),
        ),
        // Normal range overlay (60-100 BPM)
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(y1: 60, y2: 100, color: AppColors.chartNormalZone),
          ],
        ),
      ),
    );
  }
}
