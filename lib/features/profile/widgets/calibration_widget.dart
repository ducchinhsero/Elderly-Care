import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_profile.dart';

/// Widget hiển thị trạng thái calibration + nút calibrate
class CalibrationWidget extends StatelessWidget {
  final CalibrationStatus? calibration;
  final bool isCalibrating;
  final int secondsRemaining;
  final VoidCallback? onCalibrate;

  const CalibrationWidget({super.key, this.calibration, this.isCalibrating = false, this.secondsRemaining = 0, this.onCalibrate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.personalThresholds, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor().withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(), size: 16, color: _statusColor()),
                  const SizedBox(width: 6),
                  Text(_statusText(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _statusColor())),
                ],
              ),
            ),

            if (calibration?.calibratedAt != null) ...[
              const SizedBox(height: 8),
              Text('Ngày: ${calibration!.calibratedAt.toString().substring(0, 16)}',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],

            const SizedBox(height: 16),

            if (isCalibrating) ...[
              // Progress
              LinearProgressIndicator(value: 1.0 - (secondsRemaining / 1800), backgroundColor: AppColors.primary.withOpacity(0.1)),
              const SizedBox(height: 8),
              Text('${AppStrings.calibrating} ${_formatTime(secondsRemaining)}',
                style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCalibrate,
                  icon: const Icon(Icons.tune),
                  label: const Text(AppStrings.calibrateBaseline),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor() {
    if (calibration == null || !calibration!.isCalibrated) return AppColors.watch;
    if (calibration!.isExpired || calibration!.needsRecalibration) return AppColors.alert;
    return AppColors.safe;
  }

  IconData _statusIcon() {
    if (calibration == null || !calibration!.isCalibrated) return Icons.info_outline;
    if (calibration!.isExpired || calibration!.needsRecalibration) return Icons.refresh;
    return Icons.check_circle;
  }

  String _statusText() {
    if (calibration == null || !calibration!.isCalibrated) return AppStrings.notCalibrated;
    if (calibration!.isExpired || calibration!.needsRecalibration) return AppStrings.needRecalibrate;
    return AppStrings.calibrated;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
