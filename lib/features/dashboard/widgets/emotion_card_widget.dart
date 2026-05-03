import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// Card hiển thị cảm xúc (calm/stressed/positive)
class EmotionCardWidget extends StatelessWidget {
  final String emotion;
  final double confidence;

  const EmotionCardWidget({
    super.key,
    required this.emotion,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromEmotion(emotion);
    final text = AppStrings.emotionText(emotion);
    final icon = _getIcon();
    final confPercent = (confidence * 100).toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.emotion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              'Độ tin cậy: $confPercent%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (emotion.toLowerCase()) {
      case 'calm':
        return Icons.sentiment_satisfied;
      case 'stressed':
        return Icons.sentiment_very_dissatisfied;
      case 'positive':
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }
}
