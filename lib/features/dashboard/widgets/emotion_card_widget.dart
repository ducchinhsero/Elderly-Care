import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class EmotionCardWidget extends StatelessWidget {
  final String emotion; // 'Calm', 'Stressed', 'Positive', 'Unknown'
  final String activityLevel;
  final bool hasEnoughData;
  final VoidCallback onTap;

  const EmotionCardWidget({
    super.key,
    required this.emotion,
    required this.activityLevel,
    required this.hasEnoughData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isResting = activityLevel == 'REST' || activityLevel == 'SLOW_WALK';

    String title = 'Trạng thái cảm xúc';
    String description;
    IconData icon;
    Color color;

    if (!isResting) {
      description = 'Đang vận động — không đánh giá';
      icon = Icons.directions_run;
      color = AppColors.textHint;
    } else if (!hasEnoughData) {
      description = 'Đang thu thập dữ liệu... (cần 5 phút nghỉ ngơi)';
      icon = Icons.hourglass_empty;
      color = AppColors.textHint;
    } else {
      switch (emotion) {
        case 'Stressed':
          description = 'Căng thẳng';
          icon = Icons.bolt;
          color = AppColors.alert;
          break;
        case 'Positive':
          description = 'Tích cực / Phấn chấn';
          icon = Icons.sentiment_very_satisfied;
          color = AppColors.safe;
          break;
        case 'Calm':
        default:
          description = 'Bình tĩnh / Thư giãn';
          icon = Icons.self_improvement;
          color = AppColors.primary;
          break;
      }
    }

    return InkWell(
      onTap: isResting && hasEnoughData ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color == AppColors.textHint ? AppColors.textPrimary : color)),
                ],
              ),
            ),
            if (isResting && hasEnoughData)
              const Icon(Icons.info_outline, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
