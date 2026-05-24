import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/guided_baseline_model.dart';
import '../../../core/providers/vitals_provider.dart';

class CalibrationWidget extends ConsumerStatefulWidget {
  final bool isCalibrated;
  final DateTime? lastCalibratedAt;
  final bool needsRecalibration;
  final bool isCalibrating;
  final int secondsRemaining;
  final VoidCallback? onCalibrate;

  const CalibrationWidget({
    super.key,
    this.isCalibrated = false,
    this.lastCalibratedAt,
    this.needsRecalibration = false,
    this.isCalibrating = false,
    this.secondsRemaining = 0,
    this.onCalibrate,
  });

  @override
  ConsumerState<CalibrationWidget> createState() => _CalibrationWidgetState();
}

class _CalibrationWidgetState extends ConsumerState<CalibrationWidget> {
  GuidedBaselineStatus? _status;
  GuidedBaselineSession? _session;
  GuidedBaselineSegmentPlan? _activePlan;
  DateTime? _segmentStartedAt;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final json = await api.getGuidedBaselineStatus();
      final status = GuidedBaselineStatus.fromJson(json);
      setState(() {
        _status = status;
        _session = status.latestSession;
        _message = null;
      });
    } catch (e) {
      setState(() => _message = 'Khong tai duoc trang thai baseline: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startSession() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final json = await api.startGuidedBaseline();
      final session = GuidedBaselineSession.fromJson(
        json['session'] as Map<String, dynamic>,
      );
      setState(() {
        _session = session;
        _status = GuidedBaselineStatus.fromJson(json);
        _message = 'Da bat dau ngay ${session.dayIndex}/${session.targetDays}.';
      });
      await ref.read(storageServiceProvider).cacheData(
        'guided_baseline_session',
        {
          'session_id': session.sessionId,
          'day_index': session.dayIndex,
          'target_days': session.targetDays,
          'status': session.status,
        },
      );
    } catch (e) {
      setState(() => _message = 'Khong the bat dau baseline: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startSegment(GuidedBaselineSegmentPlan plan) {
    _timer?.cancel();
    setState(() {
      _activePlan = plan;
      _segmentStartedAt = DateTime.now();
      _remainingSeconds = plan.durationSeconds;
      _message = _instructionFor(plan);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activePlan == null) return;
      if (_isCurrentDataValidFor(_activePlan!)) {
        setState(() => _remainingSeconds = (_remainingSeconds - 1).clamp(0, 9999).toInt());
      } else {
        setState(() => _message = _pauseReason(_activePlan!));
      }
      if (_remainingSeconds <= 0) {
        unawaited(_completeActiveSegment());
      }
    });
  }

  Future<void> _completeActiveSegment({bool skip = false}) async {
    final plan = _activePlan;
    final session = _session;
    if (plan == null || session == null) return;
    _timer?.cancel();
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final json = await api.completeGuidedBaselineSegment(
        patientId: _status?.patientId ?? 'polar_h10',
        sessionId: session.sessionId,
        segmentType: plan.segmentType,
        startedAt: _segmentStartedAt,
        endedAt: DateTime.now(),
        allowSkip: skip,
      );
      final resultStatus = (json['status'] ?? 'unknown').toString();
      setState(() {
        _activePlan = null;
        _segmentStartedAt = null;
        _message = resultStatus == 'completed'
            ? '${plan.title} da dat yeu cau.'
            : resultStatus == 'skipped'
                ? '${plan.title} da duoc bo qua.'
                : '${plan.title} chua dat yeu cau. Hay thu lai.';
      });
      await _loadStatus();
    } catch (e) {
      setState(() => _message = 'Khong the luu segment: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeDay() async {
    final session = _session;
    if (session == null) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final json = await api.completeGuidedBaselineDay(
        patientId: _status?.patientId ?? 'polar_h10',
        sessionId: session.sessionId,
      );
      final statusJson = Map<String, dynamic>.from(json);
      statusJson['status'] = json['baseline_status'] ?? json['status'];
      setState(() {
        _status = GuidedBaselineStatus.fromJson(statusJson);
        _session = _status?.latestSession;
        _message = 'Da cap nhat baseline ca nhan cho ngay nay.';
      });
      await ref.read(storageServiceProvider).cacheData(
        'guided_baseline_last_result',
        json,
      );
    } catch (e) {
      setState(() => _message = 'Chua the hoan tat ngay baseline: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isCurrentDataValidFor(GuidedBaselineSegmentPlan plan) {
    final vitals = ref.read(vitalsProvider).currentVitals;
    if (vitals == null) return false;
    final qualityOk = vitals.hasReliableSignal;
    final activity = vitals.activity.toUpperCase();
    final expected = plan.expectedActivity.toUpperCase();
    final activityOk =
        expected == 'ACTIVE' ? activity == 'ACTIVE' || activity == 'WALK' : activity == expected;
    return qualityOk && activityOk;
  }

  String _pauseReason(GuidedBaselineSegmentPlan plan) {
    final vitals = ref.read(vitalsProvider).currentVitals;
    if (vitals == null) return 'Dang cho du lieu realtime tu Polar H10.';
    if (!vitals.hasReliableSignal) {
      return 'Tam dung: tin hieu ECG chua on dinh. Hay chinh day deo Polar H10.';
    }
    return 'Tam dung: hoat dong hien tai la ${vitals.activity}, can ${plan.expectedActivity}.';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final session = _session;
    final plans = status?.segmentPlan ?? const <GuidedBaselineSegmentPlan>[];

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
                    'Hieu chinh baseline ca nhan 7 ngay',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Tai lai',
                  onPressed: _loading ? null : _loadStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status?.statusText ??
                  'App se huong dan nguoi deo thuc hien REST, WALK va ACTIVE de baseline chinh xac hon.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status?.progressRatio.clamp(0, 1) ?? 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              status?.progressText ?? 'Chua co tien do',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _MessageBox(message: _message!),
            ],
            const SizedBox(height: 16),
            if (session == null || session.status != 'in_progress')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _startSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Bat dau huong dan hom nay'),
                ),
              )
            else ...[
              Text(
                'Ngay ${session.dayIndex}/${session.targetDays}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...plans.map((plan) => _SegmentTile(
                    plan: plan,
                    segment: _segmentFor(session, plan.segmentType),
                    active: _activePlan?.segmentType == plan.segmentType,
                    remainingSeconds: _remainingSeconds,
                    onStart: _activePlan == null && !_loading
                        ? () => _startSegment(plan)
                        : null,
                    onComplete: _activePlan?.segmentType == plan.segmentType
                        ? () => _completeActiveSegment()
                        : null,
                    onSkip: plan.skippable && _activePlan?.segmentType == plan.segmentType
                        ? () => _completeActiveSegment(skip: true)
                        : null,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _canCompleteDay(session) && !_loading ? _completeDay : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Hoan tat ngay baseline'),
                ),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  GuidedBaselineSegment? _segmentFor(GuidedBaselineSession session, String type) {
    for (final item in session.segments) {
      if (item.segmentType.toUpperCase() == type.toUpperCase()) return item;
    }
    return null;
  }

  bool _canCompleteDay(GuidedBaselineSession session) {
    if (session.segments.isEmpty) return false;
    return session.segments.every((item) =>
        item.status == 'completed' || item.status == 'skipped');
  }

  String _instructionFor(GuidedBaselineSegmentPlan plan) =>
      '${plan.userInstruction} Timer chi chay khi tin hieu tot va hoat dong khop yeu cau.';
}

class _SegmentTile extends StatelessWidget {
  final GuidedBaselineSegmentPlan plan;
  final GuidedBaselineSegment? segment;
  final bool active;
  final int remainingSeconds;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const _SegmentTile({
    required this.plan,
    required this.segment,
    required this.active,
    required this.remainingSeconds,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final status = segment?.status ?? 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(plan.segmentType), color: _colorFor(status)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: active ? 'running' : status),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.userInstruction, style: const TextStyle(fontSize: 13)),
          if (active) ...[
            const SizedBox(height: 8),
            Text(
              'Con lai ${_formatTime(remainingSeconds)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ] else if (segment != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hop le ${segment!.validWindowCount} windows, loai ${segment!.rejectedWindowCount} windows',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(status == 'failed' ? 'Thu lai' : 'Bat dau'),
              ),
              if (active) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onComplete, child: const Text('Luu ngay')),
                if (onSkip != null)
                  TextButton(onPressed: onSkip, child: const Text('Bo qua')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type.toUpperCase()) {
      case 'REST':
        return Icons.self_improvement;
      case 'WALK':
        return Icons.directions_walk;
      case 'ACTIVE':
        return Icons.accessibility_new;
      default:
        return Icons.tune;
    }
  }

  static Color _colorFor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.safe;
      case 'failed':
        return AppColors.alert;
      case 'skipped':
        return AppColors.watch;
      default:
        return AppColors.primary;
    }
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _SegmentTile._colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _text(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  String _text(String status) {
    switch (status) {
      case 'completed':
        return 'dat';
      case 'running':
        return 'dang thu';
      case 'failed':
        return 'can thu lai';
      case 'skipped':
        return 'bo qua';
      default:
        return 'cho';
    }
  }
}

class _MessageBox extends StatelessWidget {
  final String message;

  const _MessageBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13)),
    );
  }
}
