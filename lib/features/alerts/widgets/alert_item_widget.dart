import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/alert_model.dart';

class AlertItemWidget extends StatelessWidget {
  final AlertModel alert;

  const AlertItemWidget({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromAlertLevel(alert.level);
    final darkColor = AppColors.darkFromAlertLevel(alert.level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: alert.isRead
            ? Theme.of(context).cardTheme.color
            : AppColors.backgroundFromAlertLevel(alert.level),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: alert.isRead ? 0.1 : 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(), color: darkColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.alertTypeTitle(alert.type),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: alert.isRead ? AppColors.textSecondary : null),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(AppStrings.alertLevelText(alert.level), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: darkColor)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              alert.detail.isNotEmpty ? alert.detail : AppStrings.alertTypeDetail(alert.type, hr: alert.hrBpm, rmssd: alert.rmssdMs, activity: alert.activity),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(alert.relativeTime, style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                if (alert.hrBpm != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.favorite, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text('${alert.hrBpm!.toStringAsFixed(0)} BPM', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
                if (alert.activity != null) ...[
                  const SizedBox(width: 12),
                  Text(AppStrings.activityText(alert.activity!), style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (alert.type.toUpperCase()) {
      case 'TACHYCARDIA':
      case 'BRADYCARDIA':
        return Icons.favorite;
      case 'IRREGULAR_RHYTHM':
        return Icons.waves;
      case 'VERY_LOW_HRV':
        return Icons.show_chart;
      case 'FALL_DETECTED':
        return Icons.personal_injury;
      default:
        return Icons.warning_amber;
    }
  }
}
