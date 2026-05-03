import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/history_model.dart';

/// Card insights tự động từ dữ liệu
class InsightCardWidget extends StatelessWidget {
  final HistoryStats? stats;
  const InsightCardWidget({super.key, this.stats});

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: AppColors.watch),
                const SizedBox(width: 8),
                Text(AppStrings.insights, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight.text, style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  List<_Insight> _generateInsights() {
    if (stats == null) return [_Insight('📊', 'Chưa có đủ dữ liệu để phân tích')];

    final insights = <_Insight>[];

    // HR insight
    if (stats!.hrAvg > 0) {
      final hrStatus = stats!.hrAvg >= 60 && stats!.hrAvg <= 100 ? 'bình thường' : 'cần theo dõi';
      insights.add(_Insight('❤️', 'Nhịp tim trung bình hôm nay là ${stats!.hrAvg.toStringAsFixed(0)} BPM, $hrStatus'));
    }

    // HRV insight
    if (stats!.rmssdAvg > 0) {
      if (stats!.rmssdAvg < 20) {
        insights.add(_Insight('📉', 'RMSSD trung bình ${stats!.rmssdAvg.toStringAsFixed(1)} ms - khá thấp, có thể cần nghỉ ngơi thêm'));
      } else {
        insights.add(_Insight('📈', 'RMSSD trung bình ${stats!.rmssdAvg.toStringAsFixed(1)} ms - trong ngưỡng tốt'));
      }
    }

    // Alert insight
    if (stats!.alertCount > 0) {
      insights.add(_Insight('⚠️', 'Phát hiện ${stats!.alertCount} lần cảnh báo trong khoảng thời gian này'));
    } else {
      insights.add(_Insight('✅', 'Không có cảnh báo nào - tất cả chỉ số ổn định'));
    }

    // Stress insight
    final stressPercent = stats!.emotionDistribution['stressed'] ?? 0;
    if (stressPercent > 20) {
      insights.add(_Insight('😰', 'Tỉ lệ căng thẳng: ${stressPercent.toStringAsFixed(0)}% thời gian nghỉ ngơi'));
    }

    // Activity insight
    final activePercent = (stats!.activityDistribution['walk'] ?? 0) + (stats!.activityDistribution['active'] ?? 0);
    if (activePercent > 0) {
      insights.add(_Insight('🏃', 'Thời gian vận động: ${activePercent.toStringAsFixed(0)}% tổng thời gian'));
    }

    return insights;
  }
}

class _Insight {
  final String icon;
  final String text;
  const _Insight(this.icon, this.text);
}
