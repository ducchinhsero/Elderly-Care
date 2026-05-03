import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';

/// Widget slider ngưỡng HR bình thường
class AlertThresholdWidget extends StatefulWidget {
  final bool autoThresholds;
  final ValueChanged<bool> onAutoChanged;

  const AlertThresholdWidget({super.key, required this.autoThresholds, required this.onAutoChanged});

  @override
  State<AlertThresholdWidget> createState() => _AlertThresholdWidgetState();
}

class _AlertThresholdWidgetState extends State<AlertThresholdWidget> {
  RangeValues _hrRange = const RangeValues(50, 100);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(AppStrings.autoThresholds),
              subtitle: const Text(AppStrings.autoThresholdsDesc, style: TextStyle(fontSize: 12)),
              value: widget.autoThresholds,
              onChanged: widget.onAutoChanged,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            Opacity(
              opacity: widget.autoThresholds ? 0.4 : 1.0,
              child: AbsorbPointer(
                absorbing: widget.autoThresholds,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${AppStrings.hrNormalLow}: ${_hrRange.start.toInt()} BPM', style: const TextStyle(fontSize: 13)),
                        Text('${AppStrings.hrNormalHigh}: ${_hrRange.end.toInt()} BPM', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    RangeSlider(
                      values: _hrRange,
                      min: 30, max: 150,
                      divisions: 120,
                      labels: RangeLabels('${_hrRange.start.toInt()}', '${_hrRange.end.toInt()}'),
                      onChanged: (v) => setState(() => _hrRange = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
