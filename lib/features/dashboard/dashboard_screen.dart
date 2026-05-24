// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/providers/alerts_provider.dart';
import '../../core/providers/user_provider.dart';
import 'widgets/hr_gauge_widget.dart';
import 'widgets/hrv_card_widget.dart';
import 'widgets/activity_badge_widget.dart';
import 'widgets/alert_banner_widget.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/mini_hr_chart_widget.dart';
import '../reports/clinical_report_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsState = ref.watch(vitalsProvider);
    final userState = ref.watch(userProvider);
    final storage = ref.watch(storageServiceProvider);
    final isRemote = storage.isCaregiver;
    final vitals = vitalsState.currentVitals;

    // Tên hiển thị: tên người đeo (wearer) hoặc tên người được theo dõi (caregiver)
    final displayName = isRemote
        ? (storage.monitorTargetName.isNotEmpty
            ? storage.monitorTargetName
            : 'Đang theo dõi')
        : (userState.profile?.fullName ?? 'Người dùng');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              flex: 3,
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              flex: 2,
              child: ConnectionStatusWidget(),
            ),
          ],
        ),
        actions: [
          // Badge cảnh báo chưa đọc
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadAlertsCountProvider);
              return IconButton(
                onPressed: () => context.go('/alerts'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Tạo báo cáo lâm sàng',
            onSelected: (days) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ClinicalReportScreen(days: days)));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text('Hôm nay (24h qua)')),
              const PopupMenuItem(value: 7, child: Text('7 ngày qua')),
              const PopupMenuItem(value: 30, child: Text('30 ngày qua')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vitalsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Caregiver remote banner ──
              if (isRemote)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.remoteCaregiverBanner,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppStrings.remoteMode,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (vitalsState.healthReport != null &&
                  vitalsState.healthReport!.personalBaseline.status != 'ready')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.watchLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.watch.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, color: AppColors.watchDark),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Baseline ca nhan: ${vitalsState.healthReport!.personalBaseline.progressText}. Tiep tuc huong dan trong Ho so.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.watchDark,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/profile'),
                          child: const Text('Mo'),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Hero: HR Gauge ──
              HRGaugeWidget(
                hrBpm: vitals?.hrBpm ?? 0,
                alertLevel: vitals?.alertLevel ?? 'SAFE',
                conditionNameVi: vitals?.beatName ?? 'Nhịp xoang bình thường',
                confidence: 1.0 -
                    (vitals?.anomalyScore ??
                        0.0), // Mock confidence from anomaly
                hrMin: (vitals?.hrBpm ?? 60) - 4,
                hrMax: (vitals?.hrBpm ?? 60) + 7,
              ),
              const SizedBox(height: 16),

              if (vitals != null) ...[
                _ModelOutputSection(vitals: vitals),
                const SizedBox(height: 16),
              ],

              if (vitalsState.healthReport != null) ...[
                _TimeLayerReportSection(report: vitalsState.healthReport!),
                const SizedBox(height: 16),
              ],

              // ── Alert Banner (chỉ khi != SAFE) ──
              if (vitals != null && vitals.needsAttention)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AlertBannerWidget(
                    alertLevel: vitals.alertLevel,
                    clinicalAlerts: vitals.clinicalAlerts,
                    onViewDetails: () => context.go('/alerts'),
                  ),
                ),

              // ── 4 Cards row ──
              Row(
                children: [
                  Expanded(
                    child: HrvCardWidget(
                      rmssd: vitals?.rmssdMs ?? 0,
                      rmssdNormal: vitals?.rmssdNormal ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActivityBadgeWidget(
                      activity: vitals?.activity ?? 'rest',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Mini Chart: HR 30 phút ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.last30Min,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (vitals != null)
                            Text(
                              '${AppStrings.latency}: ${vitals.latencyMs.toStringAsFixed(0)} ${AppStrings.ms}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: MiniHrChartWidget(
                          dataPoints: vitalsState.recentHistory,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Timestamp & timeout ──
              if (vitalsState.isTimedOut)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.watchLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.watchDark, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.noDataTimeout,
                        style: TextStyle(
                          color: AppColors.watchDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              if (vitalsState.lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${AppStrings.lastUpdated}: ${_formatTime(vitalsState.lastUpdated!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

class _ModelOutputSection extends StatelessWidget {
  final dynamic vitals;

  const _ModelOutputSection({required this.vitals});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Kết quả phân tích từ model',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricRow(
              label: 'Nhịp tim',
              value:
                  '${vitals.rhythmLabel} | AFib ${(vitals.afibProbability * 100).round()}%',
              detail:
                  'Độ tin cậy rhythm ${(vitals.rhythmConfidence * 100).round()}%',
            ),
            const Divider(height: 16),
            _MetricRow(
              label: 'PVC/PAC',
              value: vitals.ectopyLabel,
              detail:
                  'PVC ${(vitals.pvcProbability * 100).round()}%, PAC ${(vitals.pacProbability * 100).round()}%',
            ),
            const Divider(height: 16),
            _MetricRow(
              label: 'Tín hiệu',
              value: vitals.signalQualityLabel,
              detail:
                  'Điểm ${(vitals.signalQualityScore * 100).round()}% - ${vitals.riskReason.isEmpty ? vitals.message : vitals.riskReason}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeLayerReportSection extends StatelessWidget {
  final dynamic report;

  const _TimeLayerReportSection({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined,
                    size: 20, color: _levelColor(report.overallLevel)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Báo cáo sức khỏe theo thời gian',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _LevelChip(level: report.overallLevel),
              ],
            ),
            const SizedBox(height: 12),
            _LayerTile(name: 'Hiện tại', layer: report.realtime),
            const Divider(height: 16),
            _LayerTile(name: '24 giờ', layer: report.daily),
            const Divider(height: 16),
            _LayerTile(name: 'Nhiều ngày', layer: report.longTerm),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/report'),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Xem bao cao va khuyen nghi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  final String name;
  final dynamic layer;

  const _LayerTile({required this.name, required this.layer});

  @override
  Widget build(BuildContext context) {
    final findings = layer.findings as List;
    final findingText = findings.isEmpty
        ? 'Không có phát hiện đáng chú ý'
        : findings.take(2).map((f) => f.title).join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LevelChip(level: layer.level),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      layer.windowLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                layer.summary.isEmpty ? findingText : layer.summary,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
              if (findings.isNotEmpty)
                Text(
                  findingText,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(detail,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _levelText(level),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
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
      return AppColors.safe;
    default:
      return AppColors.textSecondary;
  }
}

String _levelText(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return 'Khẩn cấp';
    case 'high':
      return 'Cao';
    case 'medium':
      return 'Theo dõi';
    case 'low':
      return 'Thấp';
    default:
      return 'Chưa đủ dữ liệu';
  }
}

/// Card cho LF/HF Ratio
class _LfHfCard extends StatelessWidget {
  final double lfHfRatio;

  const _LfHfCard({required this.lfHfRatio});

  @override
  Widget build(BuildContext context) {
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.waves,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.lfHfRatio,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lfHfRatio.toStringAsFixed(2),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _getColor(),
                  ),
            ),
            Text(
              _getDescription(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    if (lfHfRatio <= 0) return AppColors.textHint;
    if (lfHfRatio < 0.5) return AppColors.calm;
    if (lfHfRatio < 2.0) return AppColors.safe;
    if (lfHfRatio < 4.0) return AppColors.watch;
    return AppColors.alert;
  }

  String _getDescription() {
    if (lfHfRatio <= 0) return '--';
    if (lfHfRatio < 0.5) return 'Phó giao cảm ưu thế';
    if (lfHfRatio < 2.0) return 'Cân bằng';
    if (lfHfRatio < 4.0) return 'Giao cảm nhẹ';
    return 'Giao cảm mạnh';
  }
}
