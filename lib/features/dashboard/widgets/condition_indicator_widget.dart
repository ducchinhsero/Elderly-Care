import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ConditionIndicatorWidget extends StatelessWidget {
  final String conditionKey;
  final String alertLevel;
  final double confidence;
  final VoidCallback onTap;

  const ConditionIndicatorWidget({
    super.key,
    required this.conditionKey,
    required this.alertLevel,
    required this.confidence,
    required this.onTap,
  });

  static const Map<String, String> conditionNames = {
    'NSR': 'Nhịp xoang bình thường',
    'AF_NEW': 'Rung nhĩ ⚠',
    'AF_RAPID': 'Rung nhĩ nhịp nhanh 🚨',
    'PVC_ISOLATED': 'Ngoại tâm thu thất',
    'PVC_FREQUENT': 'Ngoại tâm thu thất thường xuyên ⚠',
    'ST_PATHOLOGICAL': 'Nhịp tim nhanh bất thường',
    'SB_PATHOLOGICAL': 'Nhịp tim chậm bất thường',
    'SVT': 'Nhịp nhanh trên thất ⚠',
    'VT': 'Nhịp nhanh thất 🚨',
    'LBBB_RBBB': 'Block nhánh',
    'CHF_PATTERN': 'Gợi ý suy tim ⚠',
    'EXERCISE_TACHY': 'Nhịp nhanh do vận động ✓',
    'SB_SLEEP': 'Nhịp chậm sinh lý ✓',
    'LOW_HRV_CHRONIC': 'HRV thấp kéo dài',
  };

  @override
  Widget build(BuildContext context) {
    final nameVi = conditionNames[conditionKey] ?? 'Không xác định';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), color: _getColor(), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameVi, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (confidence < 0.70)
                    const Text('(Đang phân tích)', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSeverityText(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getColor()),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    switch (alertLevel) {
      case 'WATCH': return AppColors.watch;
      case 'ALERT': return AppColors.alert;
      case 'CRITICAL': return AppColors.critical;
      case 'SAFE':
      default: return AppColors.safe;
    }
  }

  IconData _getIcon() {
    switch (alertLevel) {
      case 'WATCH': return Icons.info_outline;
      case 'ALERT': return Icons.warning_amber;
      case 'CRITICAL': return Icons.emergency;
      case 'SAFE':
      default: return Icons.favorite;
    }
  }

  String _getSeverityText() {
    switch (alertLevel) {
      case 'WATCH': return 'Theo dõi';
      case 'ALERT': return 'Cảnh báo';
      case 'CRITICAL': return 'KHẨN CẤP';
      case 'SAFE':
      default: return 'Bình thường';
    }
  }
}
