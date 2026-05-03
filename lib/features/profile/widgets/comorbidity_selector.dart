import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';

/// Multi-select chips cho bệnh nền
class ComorbiditySelectorWidget extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const ComorbiditySelectorWidget({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.comorbidities, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: AppStrings.comorbidityOptions.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (sel) {
                    final updated = List<String>.from(selected);
                    sel ? updated.add(option) : updated.remove(option);
                    onChanged(updated);
                  },
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
