import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ComorbiditySelectorWidget extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const ComorbiditySelectorWidget({super.key, required this.selected, required this.onChanged});

  static const Map<String, String> _options = {
    'hypertension': '🫀 Tăng huyết áp',
    'af_known': '💓 Rung nhĩ đã biết',
    'heart_failure': '🫀 Suy tim',
    'diabetes_t2': '🩸 Tiểu đường type 2',
    'diabetes_t1': '🩸 Tiểu đường type 1',
    'coronary_disease': '❤️🔥 Bệnh động mạch vành',
    'stroke_history': '🧠 Tiền sử đột quỵ',
    'hyperthyroidism': '🦋 Cường giáp',
    'hypothyroidism': '🦋 Suy giáp',
    'sleep_apnea': '😴 Ngưng thở khi ngủ',
    'anxiety_disorder': '😰 Rối loạn lo âu',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bệnh nền hiện có', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Chọn tất cả bệnh đang có (ảnh hưởng đến phân tích)', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _options.entries.map((entry) {
                final isSelected = selected.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (sel) {
                    final updated = List<String>.from(selected);
                    sel ? updated.add(entry.key) : updated.remove(entry.key);
                    onChanged(updated);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
            if (selected.contains('af_known')) ...[
              const SizedBox(height: 12),
              _buildInfoBanner('✓ Nhịp không đều sẽ không bị cảnh báo (đã biết trước). Chỉ cảnh báo khi HR > 130 BPM (AF đáp ứng thất nhanh).'),
            ],
            if (selected.contains('diabetes_t2') || selected.contains('diabetes_t1')) ...[
              const SizedBox(height: 8),
              _buildInfoBanner('✓ Ngưỡng biến thiên nhịp tim (HRV) được hạ thấp do ảnh hưởng thần kinh tự chủ phổ biến ở bệnh tiểu đường.'),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primary))),
        ],
      ),
    );
  }
}
