// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/providers/alerts_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/health_display_mapper.dart';
import 'widgets/hr_gauge_widget.dart';
import 'widgets/hrv_card_widget.dart';
import 'widgets/activity_badge_widget.dart';
import 'widgets/alert_banner_widget.dart';
import 'widgets/connection_status_widget.dart';
import 'widgets/mini_hr_chart_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsState = ref.watch(vitalsProvider);
    final userState = ref.watch(userProvider);
    final storage = ref.watch(storageServiceProvider);
    final isRemote = storage.isCaregiver;
    final vitals = vitalsState.isTimedOut ? null : vitalsState.currentVitals;
    final liveVitals = vitals;

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

              if (vitalsState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfflineBanner(message: vitalsState.error!),
                ),

              if (!isRemote)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RuntimeStatusCard(
                    status: vitalsState.runtimeStatus,
                    onStartPolar: () =>
                        ref.read(vitalsProvider.notifier).startPolarCollector(),
                    onOpenSettings: () => context.push('/settings'),
                  ),
                ),

              // ── Hero: HR Gauge ──
              HRGaugeWidget(
                hrBpm: liveVitals?.hrBpm ?? 0,
                alertLevel: liveVitals?.alertLevel ?? 'SAFE',
                conditionNameVi: vitals?.beatName ?? 'Nhịp tim đang đều',
                confidence: liveVitals?.signalQualityScore ?? 0.0,
                hrMin: liveVitals == null ? 0 : liveVitals.hrBpm - 4,
                hrMax: liveVitals == null ? 0 : liveVitals.hrBpm + 7,
                deviceNotWorn: liveVitals?.isDeviceNotWorn ?? false,
              ),
              const SizedBox(height: 16),

              if (vitals != null) ...[
                _FriendlyStatusSection(vitals: vitals),
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
                      const SizedBox(
                        height: 160,
                        child: _MiniHrChartSection(),
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

/// Chart cho 30 phút HR gần nhất. Tách thành ConsumerWidget `const` để khi
/// dashboard rebuild theo các thay đổi khác (runtime status mỗi 15s, health
/// report mỗi 30s, trạng thái kết nối...) thì LineChart không vẽ lại — chỉ
/// rebuild khi `recentHistory` thực sự đổi.
class _MiniHrChartSection extends ConsumerWidget {
  const _MiniHrChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(vitalsProvider.select((s) => s.recentHistory));
    return RepaintBoundary(
      child: MiniHrChartWidget(dataPoints: history),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String message;

  const _OfflineBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.watchLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.watch.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.watchDark, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.watchDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeStatusCard extends StatelessWidget {
  final DeviceRuntimeStatus status;
  final VoidCallback onStartPolar;
  final VoidCallback onOpenSettings;

  const _RuntimeStatusCard({
    required this.status,
    required this.onStartPolar,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final backendOk = status.backendReachable;
    final polarOk = status.polarRunning && status.hasRecentPrediction;
    final polarWaiting = status.polarRunning && !status.hasRecentPrediction;
    final color = !backendOk
        ? AppColors.critical
        : polarOk
            ? AppColors.safe
            : AppColors.watchDark;
    final title = !backendOk
        ? 'Raspberry chưa kết nối'
        : polarOk
            ? 'Raspberry và Polar đang hoạt động'
            : 'Raspberry đã kết nối, cần kiểm tra Polar';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  polarOk ? Icons.sensors : Icons.sensors_off_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _LevelChip(
                  level: !backendOk
                      ? 'high'
                      : polarOk
                          ? 'low'
                          : 'medium',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RuntimeLine(
              icon: Icons.router_outlined,
              text: status.networkUserLabel,
              color: backendOk ? AppColors.safe : AppColors.critical,
            ),
            const SizedBox(height: 6),
            _RuntimeLine(
              icon: Icons.monitor_heart_outlined,
              text: status.polarUserLabel,
              color: polarOk
                  ? AppColors.safe
                  : polarWaiting
                      ? AppColors.watchDark
                      : AppColors.critical,
            ),
            if ((status.polarLastError ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                status.polarLastError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Cài đặt kết nối'),
                ),
                if (!status.polarRunning)
                  ElevatedButton.icon(
                    onPressed: backendOk ? onStartPolar : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Bật thu Polar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _RuntimeLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FriendlyStatusSection extends StatelessWidget {
  final dynamic vitals;

  const _FriendlyStatusSection({required this.vitals});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromAlertLevel(vitals.alertLevel);
    final primaryAlert =
        vitals.clinicalAlerts.isNotEmpty ? vitals.clinicalAlerts.first : null;
    final whatHappened = primaryAlert == null
        ? HealthDisplayMapper.rhythmSummary(
            vitals.rhythmLabel,
            vitals.afibProbability,
          )
        : HealthDisplayMapper.alertTitle(primaryAlert.type);
    final why = primaryAlert == null
        ? 'Dựa trên nhịp tim, chất lượng tín hiệu và lần đo gần nhất.'
        : HealthDisplayMapper.alertWhy(primaryAlert.type);
    final action = primaryAlert == null
        ? HealthDisplayMapper.levelAction(vitals.alertLevel)
        : HealthDisplayMapper.alertAction(primaryAlert.type, vitals.alertLevel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tình trạng hiện tại',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _LevelChip(level: vitals.alertLevel),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleInfoRow(
              icon: Icons.info_outline,
              title: 'Tình trạng',
              text: whatHappened,
              color: color,
            ),
            const SizedBox(height: 10),
            _SimpleInfoRow(
              icon: Icons.help_outline,
              title: 'Vì sao cần chú ý',
              text: why,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _SimpleInfoRow(
              icon: Icons.task_alt,
              title: 'Việc nên làm',
              text: action,
              color: color,
              emphasize: true,
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MeasuredChip(
                  icon: Icons.favorite,
                  label: 'Nhịp tim',
                  value: vitals.hasHr ? '${vitals.hrText} BPM' : 'Chưa đo được',
                ),
                _MeasuredChip(
                  icon: Icons.monitor_heart_outlined,
                  label: HealthDisplayMapper.metricLabel('hrv'),
                  value: vitals.rmssdMs > 0
                      ? '${vitals.rmssdMs.toStringAsFixed(1)} ms'
                      : 'Chưa đủ dữ liệu',
                ),
                _MeasuredChip(
                  icon: Icons.sensors_outlined,
                  label: 'Chất lượng đo',
                  value: HealthDisplayMapper.signalLabel(
                    vitals.signalQualityLabel,
                  ),
                ),
                _MeasuredChip(
                  icon: Icons.psychology_alt_outlined,
                  label: 'Stress',
                  value: _stressText(
                    vitals.stressLabel,
                    vitals.stressConfidence,
                    vitals.stressReason,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _stressText(String label, double confidence, String reason) {
  if (label == 'unknown') {
    if (reason == 'warming_up_stress_window') {
      return 'Đang thu đủ 5 phút';
    }
    return 'Chưa đủ dữ liệu';
  }
  final pct = (confidence * 100).round();
  if (label == 'stress') return 'Căng thẳng $pct%';
  if (label == 'non_stress') return 'Ổn định $pct%';
  return label;
}

class _SimpleInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final bool emphasize;

  const _SimpleInfoRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasize ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasuredChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MeasuredChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ModelOutputSection extends StatelessWidget {
  final dynamic vitals;

  const _ModelOutputSection({required this.vitals});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.data_object, color: AppColors.primary),
        title: const Text(
          'Xem dữ liệu kỹ thuật lượt đo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Dành cho người chăm sóc hoặc kỹ thuật viên',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricRow(
                label: 'Rhythm',
                value:
                    '${vitals.rhythmLabel} | possible_afib ${(vitals.afibProbability * 100).round()}%',
                detail:
                    'Người dùng thấy: ${HealthDisplayMapper.rhythmSummary(vitals.rhythmLabel, vitals.afibProbability)}',
              ),
              const Divider(height: 16),
              _MetricRow(
                label: 'Ectopy',
                value: vitals.ectopyLabel,
                detail:
                    'PVC ${(vitals.pvcProbability * 100).round()}%, PAC ${(vitals.pacProbability * 100).round()}% | Người dùng thấy: ${HealthDisplayMapper.ectopySummary(vitals.ectopyLabel)}',
              ),
              const Divider(height: 16),
              _MetricRow(
                label: 'Anomaly',
                value: vitals.anomalyLabel,
                detail: vitals.anomalyLabel == 'abnormal'
                    ? 'Tin hieu sang loc bat thuong ECG. Can xem cung chat luong tin hieu, rhythm va lich su.'
                    : 'Khong ghi nhan bat thuong ECG tu model anomaly trong cua so gan nhat.',
              ),
              const Divider(height: 16),
              _MetricRow(
                label: 'Signal',
                value:
                    '${vitals.signalQualityLabel} (${(vitals.signalQualityScore * 100).round()}%)',
                detail:
                    '${HealthDisplayMapper.signalLabel(vitals.signalQualityLabel)} - ${vitals.riskReason.isEmpty ? vitals.message : vitals.riskReason}',
              ),
            ],
          ),
        ],
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
                    'Tóm tắt sức khỏe theo thời gian',
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
                label: const Text('Xem tóm tắt và khuyến nghị'),
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
  return HealthDisplayMapper.levelLabel(level);
}
