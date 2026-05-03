import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MedicationSelectorWidget extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MedicationSelectorWidget({super.key, required this.selected, required this.onChanged});

  static const Map<String, String> _options = {
    'beta_blocker': '💊 Chẹn beta (metoprolol...)',
    'calcium_blocker': '💊 Chẹn kênh Canxi (amlodipine...)',
    'ace_inhibitor': '💊 Ức chế men chuyển',
    'anticoagulant': '💊 Chống đông máu',
    'antiarrhythmic': '💊 Thuốc chống loạn nhịp',
    'digoxin': '💊 Digoxin',
    'pacemaker': '🔧 Đang có máy tạo nhịp',
    'thyroid_medication': '💊 Thuốc tuyến giáp',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thuốc đang dùng thường xuyên', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Một số thuốc ảnh hưởng đến nhịp tim và ngưỡng cảnh báo', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
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
            if (selected.contains('beta_blocker')) ...[
              const SizedBox(height: 12),
              _buildInfoBanner('✓ Ngưỡng nhịp chậm điều chỉnh: cảnh báo dưới 45 BPM (thay vì 50 BPM). HR thấp 45-60 là bình thường khi dùng chẹn beta.'),
            ],
            if (selected.contains('pacemaker')) ...[
              const SizedBox(height: 8),
              _buildInfoBanner('✓ Nhịp đều và chậm sẽ không bị cảnh báo. Chỉ theo dõi các bất thường trên nhịp tạo nhịp.'),
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
