import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/history_provider.dart';
import '../../core/models/history_model.dart';
import 'widgets/daily_summary_widget.dart';
import 'widgets/insight_card_widget.dart';

class HealthReportScreen extends ConsumerWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final stats = historyState.historyData?.stats;
    final score = _calculateScore(stats);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.healthReport),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _share(context, stats, score)),
        ],
      ),
      body: historyState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Score circle
                  DailySummaryWidget(score: score, stats: stats),
                  const SizedBox(height: 16),

                  // Insights
                  InsightCardWidget(stats: stats),
                  const SizedBox(height: 16),

                  // Comparison cards
                  _ComparisonSection(stats: stats),
                  const SizedBox(height: 16),

                  // Export buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportPdf(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text(AppStrings.exportPdf),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _share(context, stats, score),
                          icon: const Icon(Icons.share),
                          label: const Text(AppStrings.share),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  int _calculateScore(HistoryStats? stats) {
    if (stats == null) return 0;
    double score = 0;
    // % thời gian HR bình thường (max 40 điểm)
    score += (stats.normalPercent / 100) * 40;
    // RMSSD avg so với baseline 25ms (max 30 điểm)
    final rmssdScore = (stats.rmssdAvg / 30).clamp(0, 1) * 30;
    score += rmssdScore;
    // Ít alerts (max 30 điểm)
    final alertPenalty = (stats.alertCount * 5).clamp(0, 30);
    score += (30 - alertPenalty);
    return score.round().clamp(0, 100);
  }

  void _exportPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng xuất PDF sẽ được cập nhật')));
  }

  void _share(BuildContext context, HistoryStats? stats, int score) {
    if (stats == null) return;
    final text = '''
🏥 Báo cáo sức khỏe - ${DateTime.now().toString().substring(0, 10)}
━━━━━━━━━━━━━━━
📊 Điểm sức khỏe: $score/100
❤️ Nhịp tim TB: ${stats.hrAvg.toStringAsFixed(0)} BPM
📈 RMSSD TB: ${stats.rmssdAvg.toStringAsFixed(1)} ms
⚠️ Số cảnh báo: ${stats.alertCount}
✅ Thời gian bình thường: ${stats.normalPercent.toStringAsFixed(0)}%
''';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã sao chép báo cáo')));
  }
}

class _ComparisonSection extends StatelessWidget {
  final HistoryStats? stats;
  const _ComparisonSection({this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.comparison, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _CompRow(label: 'HR trung bình', value: '${stats!.hrAvg.toStringAsFixed(0)} BPM', trend: '→', color: AppColors.primary),
            const Divider(height: 16),
            _CompRow(label: 'RMSSD trung bình', value: '${stats!.rmssdAvg.toStringAsFixed(1)} ms', trend: '→', color: AppColors.primary),
            const Divider(height: 16),
            _CompRow(label: AppStrings.avgAlerts, value: '${stats!.alertCount}', trend: stats!.alertCount > 3 ? '↑' : '↓', color: stats!.alertCount > 3 ? AppColors.alert : AppColors.safe),
          ],
        ),
      ),
    );
  }
}

class _CompRow extends StatelessWidget {
  final String label, value, trend;
  final Color color;
  const _CompRow({required this.label, required this.value, required this.trend, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(trend, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
