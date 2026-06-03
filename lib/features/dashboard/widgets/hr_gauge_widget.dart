import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class HRGaugeWidget extends StatelessWidget {
  final double hrBpm;
  final String alertLevel;
  final String conditionNameVi;
  final double confidence;
  final double hrMin;
  final double hrMax;
  final VoidCallback? onTap;

  const HRGaugeWidget({
    super.key,
    required this.hrBpm,
    required this.alertLevel,
    required this.conditionNameVi,
    required this.confidence,
    required this.hrMin,
    required this.hrMax,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLiveHr = hrBpm > 0;
    final color = hasLiveHr ? _levelColor() : AppColors.watchDark;
    final hr = hrBpm <= 0 ? null : hrBpm.round();
    final normalized = hrBpm <= 0 ? 0.0 : ((hrBpm - 40) / 120).clamp(0.0, 1.0);
    final hrAvg = ((hrMin + hrMax) / 2).round();
    final statusLabel = hasLiveHr ? _levelText() : 'Chờ dữ liệu';
    final conditionText =
        hasLiveHr ? conditionNameVi : 'Chưa có dữ liệu ECG mới';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.favorite, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Nhịp tim',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(label: statusLabel, color: color),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hr?.toString() ?? '--',
                    style: TextStyle(
                      fontSize: 52,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasLiveHr && confidence < 0.8) const _AnalyzingChip(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                conditionText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _HeartRateRangeBar(value: normalized, color: color),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('40', style: _AxisStyle()),
                  Text('50-100 bình thường', style: _AxisStyle()),
                  Text('160+', style: _AxisStyle()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _MiniMetric(label: 'Thấp', value: hrMin.round())),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniMetric(label: 'TB', value: hrAvg)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MiniMetric(label: 'Cao', value: hrMax.round())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor() {
    switch (alertLevel.toUpperCase()) {
      case 'WATCH':
        return AppColors.watchDark;
      case 'ALERT':
        return AppColors.alert;
      case 'CRITICAL':
        return AppColors.critical;
      case 'SAFE':
      default:
        return AppColors.safe;
    }
  }

  String _levelText() {
    switch (alertLevel.toUpperCase()) {
      case 'WATCH':
        return 'Theo dõi';
      case 'ALERT':
        return 'Cảnh báo';
      case 'CRITICAL':
        return 'Nguy hiểm';
      case 'SAFE':
      default:
        return 'Ổn định';
    }
  }
}

class _HeartRateRangeBar extends StatelessWidget {
  final double value;
  final Color color;

  const _HeartRateRangeBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final markerLeft = (constraints.maxWidth * value - 6)
            .clamp(0.0, constraints.maxWidth - 12);
        return SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(height: 10, color: AppColors.watchLight),
                    ),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 10,
                        color: AppColors.safe.withValues(alpha: 0.35),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 10,
                        color: AppColors.alert.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: markerLeft,
                child: Container(
                  width: 12,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _AnalyzingChip extends StatelessWidget {
  const _AnalyzingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Đang phân tích',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final int value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value > 0 ? value.toString() : '--',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisStyle extends TextStyle {
  const _AxisStyle()
      : super(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textHint,
        );
}
