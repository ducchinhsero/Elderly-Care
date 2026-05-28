import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/health_display_mapper.dart';

/// Card hiển thị mức phục hồi/căng thẳng cơ thể với icon tim.
class HrvCardWidget extends StatelessWidget {
  final double rmssd;
  final String rmssdNormal;

  const HrvCardWidget({
    super.key,
    required this.rmssd,
    required this.rmssdNormal,
  });

  @override
  Widget build(BuildContext context) {
    final hasRmssd = rmssd > 0;

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
                    color: AppColors.critical.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_heart,
                    size: 18,
                    color: AppColors.critical,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    HealthDisplayMapper.metricLabel('hrv'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasRmssd)
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: rmssd.toStringAsFixed(1),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _getColor(),
                              ),
                    ),
                    TextSpan(
                      text: ' ms',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Chưa đủ dữ liệu',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
              ),
            if (rmssdNormal.isNotEmpty)
              Text(
                hasRmssd
                    ? rmssdNormal
                    : 'Chưa đủ dữ liệu để ước tính mức phục hồi.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    if (rmssd <= 0) return AppColors.textHint;
    if (rmssd < 15) return AppColors.alert;
    if (rmssd < 20) return AppColors.watch;
    if (rmssd < 50) return AppColors.safe;
    return AppColors.calm;
  }
}
