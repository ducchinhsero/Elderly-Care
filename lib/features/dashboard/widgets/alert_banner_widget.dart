import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/vitals_model.dart';

/// Banner cảnh báo khi alert_level != SAFE
class AlertBannerWidget extends StatelessWidget {
  final String alertLevel;
  final List<ClinicalAlert> clinicalAlerts;
  final VoidCallback? onViewDetails;

  const AlertBannerWidget({
    super.key,
    required this.alertLevel,
    required this.clinicalAlerts,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromAlertLevel(alertLevel);
    final bgColor = AppColors.backgroundFromAlertLevel(alertLevel);
    final darkColor = AppColors.darkFromAlertLevel(alertLevel);
    final isCritical = alertLevel.toUpperCase() == 'CRITICAL';

    final firstAlert = clinicalAlerts.isNotEmpty
        ? clinicalAlerts.first
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: isCritical ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCritical ? Icons.error : Icons.warning_amber,
              color: darkColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.alertLevelText(alertLevel),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                    letterSpacing: 0.5,
                  ),
                ),
                if (firstAlert != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.alertTypeTitle(firstAlert.type),
                    style: TextStyle(
                      fontSize: 12,
                      color: darkColor.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onViewDetails,
            style: TextButton.styleFrom(
              foregroundColor: darkColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              AppStrings.viewDetails,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
