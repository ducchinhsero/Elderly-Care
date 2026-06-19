import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/health_report_model.dart';
import '../../core/models/history_model.dart';
import '../../core/providers/history_provider.dart';
import '../../core/providers/vitals_provider.dart';
import 'widgets/daily_summary_widget.dart';
import 'widgets/insight_card_widget.dart';

class HealthReportScreen extends ConsumerWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final vitalsState = ref.watch(vitalsProvider);
    final healthReport = vitalsState.healthReport;
    final stats = historyState.historyData?.stats;
    final score = _calculateScore(stats);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.healthReport),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Báo cáo theo ngày',
            onPressed: () => context.push('/daily-report'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(vitalsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, healthReport, stats, score),
          ),
        ],
      ),
      body: historyState.isLoading && healthReport == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(vitalsProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vitalsState.error != null)
                      _InfoBanner(
                        icon: Icons.info_outline,
                        text: vitalsState.error!,
                        color: AppColors.watchDark,
                      ),
                    if (healthReport == null)
                      const _EmptyReportCard()
                    else ...[
                      _OverallAssessmentCard(report: healthReport),
                      const SizedBox(height: 16),
                      _TimeLayerCard(report: healthReport),
                      const SizedBox(height: 16),
                      _FindingsCard(report: healthReport),
                      const SizedBox(height: 16),
                      _PersonalBaselineCard(
                        baseline: healthReport.personalBaseline,
                      ),
                      const SizedBox(height: 16),
                      _DisclaimerCard(disclaimer: healthReport.disclaimer),
                      const SizedBox(height: 16),
                    ],
                    DailySummaryWidget(score: score, stats: stats),
                    const SizedBox(height: 16),
                    InsightCardWidget(stats: stats),
                    const SizedBox(height: 16),
                    _ComparisonSection(stats: stats),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportPdf(context),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text(AppStrings.exportPdf),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _share(context, healthReport, stats, score),
                            icon: const Icon(Icons.share),
                            label: const Text(AppStrings.share),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  int _calculateScore(HistoryStats? stats) {
    if (stats == null) return 0;
    double score = 0;
    score += (stats.normalPercent / 100) * 40;
    final rmssdScore = (stats.rmssdAvg / 30).clamp(0, 1) * 30;
    score += rmssdScore;
    final alertPenalty = (stats.alertCount * 5).clamp(0, 30);
    score += (30 - alertPenalty);
    return score.round().clamp(0, 100);
  }

  void _exportPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tinh nang xuat PDF se duoc cap nhat')),
    );
  }

  void _share(
    BuildContext context,
    HealthReportModel? report,
    HistoryStats? stats,
    int score,
  ) {
    final now = DateTime.now().toString().substring(0, 10);
    final buffer = StringBuffer()
      ..writeln('Tóm tắt sức khỏe - $now')
      ..writeln('Điểm tổng quan: $score/100');

    if (report != null) {
      buffer
        ..writeln('Mức hiện tại: ${report.userLevelText}')
        ..writeln(report.overallSummary.isEmpty
            ? report.userActionText
            : report.overallSummary)
        ..writeln('Việc nên làm: ${report.userActionText}');
      if (report.hasFindings) {
        buffer.writeln('Điểm cần chú ý:');
        for (final finding in report.importantFindings.take(3)) {
          buffer.writeln('- ${finding.displayTitle}: ${finding.actionText}');
        }
      }
    }

    if (stats != null) {
      buffer
        ..writeln('Nhịp tim trung bình: ${stats.hrAvg.toStringAsFixed(0)} BPM')
        ..writeln('Số cảnh báo: ${stats.alertCount}')
        ..writeln(
          'Thời gian ổn định: ${stats.normalPercent.toStringAsFixed(0)}%',
        );
    }

    buffer.writeln(
        'Lưu ý: đây là dữ liệu theo dõi/sàng lọc, không phải chẩn đoán y khoa.');
    Share.share(buffer.toString(), subject: AppStrings.healthReport);
  }
}

class _OverallAssessmentCard extends StatelessWidget {
  final HealthReportModel report;

  const _OverallAssessmentCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(report.overallLevel);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.health_and_safety_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tóm tắt dễ hiểu',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.userLevelText,
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _LevelChip(level: report.overallLevel),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.overallSummary.isEmpty
                  ? 'Hệ thống đang tổng hợp tình trạng từ lần đo gần nhất, 24 giờ và nhiều ngày.'
                  : report.overallSummary,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            _ActionBox(text: report.userActionText, level: report.overallLevel),
          ],
        ),
      ),
    );
  }
}

class _TimeLayerCard extends StatelessWidget {
  final HealthReportModel report;

  const _TimeLayerCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.timeline_outlined,
              title: 'Theo dõi theo thời gian',
              subtitle: 'Tách riêng hiện tại, 24 giờ và xu hướng nhiều ngày.',
            ),
            const SizedBox(height: 12),
            _LayerRow(label: 'Hiện tại', layer: report.realtime),
            const Divider(height: 18),
            _LayerRow(label: '24 giờ gần nhất', layer: report.daily),
            const Divider(height: 18),
            _LayerRow(label: '7 ngày gần nhất', layer: report.longTerm),
          ],
        ),
      ),
    );
  }
}

class _FindingsCard extends StatelessWidget {
  final HealthReportModel report;

  const _FindingsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final findings = report.importantFindings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.manage_search,
              title: 'Điểm cần chú ý và việc nên làm',
              subtitle:
                  'Các mục này là dữ liệu theo dõi/sàng lọc, không phải chẩn đoán.',
            ),
            const SizedBox(height: 12),
            if (findings.isEmpty)
              _InfoBanner(
                icon: Icons.check_circle_outline,
                text:
                    'Chưa phát hiện điểm đáng chú ý trong dữ liệu hiện có. Tiếp tục theo dõi định kỳ.',
                color: AppColors.safe,
              )
            else
              ...findings.take(6).map((finding) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FindingTile(finding: finding),
                  )),
          ],
        ),
      ),
    );
  }
}

class _PersonalBaselineCard extends StatelessWidget {
  final PersonalBaseline baseline;

  const _PersonalBaselineCard({required this.baseline});

  @override
  Widget build(BuildContext context) {
    final rows = baseline.comparisonRows;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.person_search_outlined,
              title: 'So sánh với mức bình thường của riêng bạn',
              subtitle:
                  'Dùng để xem thay đổi so với mức thường thấy của người dùng.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    baseline.statusText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _BaselineStatusChip(status: baseline.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              baseline.progressText,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(
                'Chưa đủ dữ liệu so sánh. Hãy để thiết bị thu dữ liệu tốt trong các ngày đầu sử dụng.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...rows.map((row) => _BaselineRow(row: row)),
            const SizedBox(height: 8),
            Text(
              'Không dùng mức bình thường riêng để kết luận bệnh; chỉ dùng để phát hiện thay đổi cần theo dõi.',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final HealthFinding finding;

  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(finding.level);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_findingIcon(finding.type), color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _LevelChip(level: finding.level),
            ],
          ),
          if (finding.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(finding.reason, style: const TextStyle(height: 1.35)),
          ],
          finalEvidenceText(finding.evidence).isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    finalEvidenceText(finding.evidence),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          _ActionBox(text: finding.actionText, level: finding.level),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final String label;
  final HealthLayer layer;

  const _LayerRow({required this.label, required this.layer});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LevelChip(level: layer.level),
                  Text(
                    layer.windowLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                layer.summary.isEmpty
                    ? (layer.findings.isEmpty
                        ? 'Chua co phat hien dang chu y.'
                        : layer.findings.first.displayTitle)
                    : layer.summary,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBox extends StatelessWidget {
  final String text;
  final String level;

  const _ActionBox({required this.text, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.medical_information_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BaselineRow extends StatelessWidget {
  final BaselineComparison row;

  const _BaselineRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final value = row.value ?? 0;
    final color = value.abs() < (row.isPercent ? 0.01 : 3.0)
        ? AppColors.safe
        : value > 0
            ? AppColors.watchDark
            : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(row.label)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.displayValue,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                row.interpretation,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaselineStatusChip extends StatelessWidget {
  final String status;

  const _BaselineStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.toLowerCase() == 'ready'
        ? AppColors.safe
        : status.toLowerCase() == 'warming_up'
            ? AppColors.watchDark
            : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String level;

  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        healthLevelText(level),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final String disclaimer;

  const _DisclaimerCard({required this.disclaimer});

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      icon: Icons.info_outline,
      text: disclaimer.isEmpty
          ? 'Đây là dữ liệu theo dõi/sàng lọc, không phải chẩn đoán y khoa.'
          : disclaimer,
      color: AppColors.textSecondary,
    );
  }
}

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            const Text(
              'Chưa đủ dữ liệu để tóm tắt',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Hãy bật thiết bị và thu thêm dữ liệu đo tốt để tạo tóm tắt sức khỏe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  final HistoryStats? stats;
  const _ComparisonSection({this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.comparison,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _CompRow(
              label: 'Nhịp tim trung bình',
              value: '${stats!.hrAvg.toStringAsFixed(0)} BPM',
              trend: '--',
              color: AppColors.primary,
            ),
            const Divider(height: 16),
            _CompRow(
              label: 'Mức phục hồi trung bình',
              value: '${stats!.rmssdAvg.toStringAsFixed(1)} ms',
              trend: '--',
              color: AppColors.primary,
            ),
            const Divider(height: 16),
            _CompRow(
              label: AppStrings.avgAlerts,
              value: '${stats!.alertCount}',
              trend: stats!.alertCount > 3 ? 'Tăng' : 'Ổn',
              color: stats!.alertCount > 3 ? AppColors.alert : AppColors.safe,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompRow extends StatelessWidget {
  final String label, value, trend;
  final Color color;
  const _CompRow({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text(
          trend,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

Color _levelColor(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return AppColors.critical;
    case 'high':
      return AppColors.alert;
    case 'medium':
      return AppColors.watchDark;
    case 'low':
    case 'normal':
      return AppColors.safe;
    default:
      return AppColors.textSecondary;
  }
}

IconData _findingIcon(String type) {
  final key = type.toLowerCase();
  if (key.contains('afib') || key.contains('rhythm')) return Icons.waves;
  if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
    return Icons.monitor_heart_outlined;
  }
  if (key.contains('heart') || key.contains('tachy') || key.contains('brady')) {
    return Icons.favorite_outline;
  }
  if (key.contains('fall')) return Icons.personal_injury_outlined;
  if (key.contains('signal')) return Icons.sensors_off_outlined;
  return Icons.warning_amber_outlined;
}

String finalEvidenceText(Map<String, dynamic> evidence) {
  if (evidence.isEmpty) return '';
  return evidence.entries
      .take(4)
      .map((entry) =>
          '${_evidenceLabel(entry.key)}: ${_formatValue(entry.value)}')
      .join(' | ');
}

String _evidenceLabel(String key) {
  switch (key) {
    case 'event_count':
      return 'Số lần';
    case 'max_afib_probability':
      return 'Nhịp không đều cao nhất';
    case 'af_suspicion_window_ratio':
      return 'Tỉ lệ nghi ngờ nhịp không đều';
    case 'max_af_burden_percent':
      return 'AF burden';
    case 'tachycardia_event_count':
      return 'Nhanh';
    case 'bradycardia_event_count':
      return 'Chậm';
    case 'good_signal_ratio':
      return 'Tín hiệu tốt';
    case 'poor_signal_event_count':
      return 'Tín hiệu kém';
    default:
      return key.replaceAll('_', ' ');
  }
}

String _formatValue(dynamic value) {
  if (value is num) {
    if (value.abs() <= 1 && value != 0) {
      return '${(value * 100).toStringAsFixed(0)}%';
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
  return value?.toString() ?? '--';
}
