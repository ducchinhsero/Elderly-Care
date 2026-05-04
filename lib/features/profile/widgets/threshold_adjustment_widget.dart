import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_profile.dart';

class ThresholdAdjustmentWidget extends StatelessWidget {
  final UserProfile profile;

  const ThresholdAdjustmentWidget({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final effective = profile.effectiveThresholds;
    final bool hasAdjustments = profile.comorbidities.isNotEmpty || profile.medications.isNotEmpty;

    if (!hasAdjustments) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ngưỡng cảnh báo đã điều chỉnh',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Chỉ số', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Mặc định', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Của bạn', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: [
                  _buildRow('HR thấp (ALERT)', '< 50 BPM', '< ${effective['hr_low'].toInt()} BPM ${effective['hr_low'] < 50 ? '*' : ''}'),
                  _buildRow('HR cao (ALERT)', '> 100 BPM', '> ${effective['hr_high'].toInt()} BPM ${effective['hr_high'] > 100 ? '*' : ''}'),
                  _buildRow('HR cao (CRITICAL)', '> 130 BPM', '> ${effective['hr_critical'].toInt()} BPM ${effective['hr_critical'] > 130 ? '*' : ''}'),
                  _buildRow('Nhịp không đều', 'Cảnh báo', effective['warn_irregular'] ? 'Cảnh báo' : 'Không c/b *'),
                  _buildRow('RMSSD thấp', '< 18 ms', '< ${effective['rmssd_min'].toInt()} ms ${effective['rmssd_min'] < 18 ? '*' : ''}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Lý do điều chỉnh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                if (profile.medications.contains('beta_blocker'))
                  const ListTile(dense: true, title: Text('* HR thấp 45 BPM: Vì đang dùng chẹn beta')),
                if (profile.comorbidities.contains('af_known'))
                  const ListTile(dense: true, title: Text('* Nhịp không đều: Vì đã có rung nhĩ từ trước')),
                if (profile.comorbidities.contains('diabetes_t2') || profile.comorbidities.contains('diabetes_t1'))
                  const ListTile(dense: true, title: Text('* RMSSD 13 ms: Điều chỉnh theo tuổi và tiểu đường')),
                if (profile.medications.contains('pacemaker'))
                  const ListTile(dense: true, title: Text('* Không c/b nhịp đều chậm: Vì đang dùng máy tạo nhịp')),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showDetailsDialog(context),
                child: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giải thích ngưỡng cảnh báo'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Các ngưỡng cảnh báo được AI tự động tính toán dựa trên độ tuổi, giới tính, bệnh nền và thuốc đang dùng của bạn để giảm thiểu cảnh báo giả.\n'),
              Text('• HR thấp / cao: Là nhịp tim dưới hoặc trên mức cho phép. Nếu bạn đang dùng thuốc chẹn beta, nhịp tim thường sẽ chậm hơn người bình thường.\n'),
              Text('• Nhịp không đều: Là dấu hiệu của rối loạn nhịp. Tuy nhiên nếu bạn đã được chẩn đoán rung nhĩ từ trước, hệ thống sẽ bỏ qua để tránh làm phiền bạn liên tục.\n'),
              Text('• RMSSD: Là chỉ số đo độ biến thiên nhịp tim. Người lớn tuổi hoặc có bệnh tiểu đường thường có mức RMSSD tự nhiên thấp hơn.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  DataRow _buildRow(String label, String defaultVal, String yourVal) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(fontSize: 13))),
        DataCell(Text(defaultVal, style: const TextStyle(fontSize: 13, color: AppColors.textHint))),
        DataCell(Text(yourVal, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: yourVal.contains('*') ? AppColors.primary : null))),
      ],
    );
  }
}
