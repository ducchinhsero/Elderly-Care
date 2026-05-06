import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/providers/alerts_provider.dart';
import '../../core/providers/user_provider.dart';
import 'widgets/hr_gauge_widget.dart';
import 'widgets/condition_indicator_widget.dart';
import 'widgets/hrv_card_widget.dart';
import 'widgets/activity_badge_widget.dart';
import 'widgets/emotion_card_widget.dart';
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
        title: Row(
          children: [
            Text(displayName),
            const SizedBox(width: 8),
            const ConnectionStatusWidget(),
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
                MaterialPageRoute(builder: (_) => ClinicalReportScreen(days: days))
              );
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: AppColors.primary, size: 18),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppStrings.remoteMode,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
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
                confidence: 1.0 - (vitals?.anomalyScore ?? 0.0), // Mock confidence from anomaly
                hrMin: (vitals?.hrBpm ?? 60) - 4,
                hrMax: (vitals?.hrBpm ?? 60) + 7,
              ),
              const SizedBox(height: 16),

              // ── Tình trạng tim ──
              ConditionIndicatorWidget(
                conditionKey: vitals?.beatType ?? 'NSR',
                alertLevel: vitals?.alertLevel ?? 'SAFE',
                confidence: 1.0 - (vitals?.anomalyScore ?? 0.0),
                onTap: () {
                  // TODO: Navigate to Condition Detail
                },
              ),
              const SizedBox(height: 16),

              // ── Trạng thái cảm xúc ──
              EmotionCardWidget(
                emotion: vitals?.emotion ?? 'Calm',
                activityLevel: vitals?.activity ?? 'REST',
                hasEnoughData: true, // Mocked for demo
                onTap: () {
                  // TODO: Navigate to Emotion Detail
                },
              ),
              const SizedBox(height: 20),

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
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (vitals != null)
                            Text(
                              '${AppStrings.latency}: ${vitals.latencyMs.toStringAsFixed(0)} ${AppStrings.ms}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.watchLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.watchDark, size: 18),
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
