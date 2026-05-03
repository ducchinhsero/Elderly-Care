import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/history_model.dart';

/// Vòng tròn score sức khỏe tổng thể
class DailySummaryWidget extends StatelessWidget {
  final int score;
  final HistoryStats? stats;

  const DailySummaryWidget({super.key, required this.score, this.stats});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('${AppStrings.dailyReport} ${DateTime.now().toString().substring(0, 10)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            SizedBox(
              width: 150, height: 150,
              child: CustomPaint(
                painter: _ScoreRingPainter(score: score / 100, color: color),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: color)),
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),
            if (stats != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniStat(icon: Icons.favorite, value: '${stats!.hrAvg.toStringAsFixed(0)}', unit: 'BPM'),
                  _MiniStat(icon: Icons.show_chart, value: '${stats!.rmssdAvg.toStringAsFixed(1)}', unit: 'ms'),
                  _MiniStat(icon: Icons.warning_amber, value: '${stats!.alertCount}', unit: 'alerts'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    if (score >= 80) return AppColors.safe;
    if (score >= 50) return AppColors.watch;
    return AppColors.alert;
  }

  String _getLabel() {
    if (score >= 80) return AppStrings.scoreGood;
    if (score >= 50) return AppStrings.scoreAverage;
    return AppStrings.scoreNeedAttention;
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double score;
  final Color color;
  _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final bg = Paint()..color = color.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi, false, bg);

    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * score, false, fg);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) => old.score != score || old.color != color;
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value, unit;
  const _MiniStat({required this.icon, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(unit, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }
}
