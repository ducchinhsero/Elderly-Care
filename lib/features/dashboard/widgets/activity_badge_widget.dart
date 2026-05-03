import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// Card hiển thị trạng thái hoạt động (rest/walk/active)
class ActivityBadgeWidget extends StatelessWidget {
  final String activity;

  const ActivityBadgeWidget({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromActivity(activity);
    final text = AppStrings.activityText(activity);
    final icon = _getIcon();

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
                    color: color.withValues(alpha: 0.15),
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
                  AppStrings.activity,
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
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (activity.toLowerCase()) {
      case 'rest':
        return Icons.self_improvement;
      case 'slow_walk':
        return Icons.directions_walk;
      case 'walk':
        return Icons.directions_walk;
      case 'active':
        return Icons.directions_run;
      default:
        return Icons.accessibility_new;
    }
  }
}
