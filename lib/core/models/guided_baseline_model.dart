class GuidedBaselineStatus {
  final String patientId;
  final String status;
  final int dayCount;
  final int targetDays;
  final double progressRatio;
  final List<GuidedBaselineSegmentPlan> segmentPlan;
  final GuidedBaselineSession? latestSession;

  const GuidedBaselineStatus({
    required this.patientId,
    required this.status,
    required this.dayCount,
    required this.targetDays,
    required this.progressRatio,
    required this.segmentPlan,
    this.latestSession,
  });

  factory GuidedBaselineStatus.fromJson(Map<String, dynamic> json) {
    return GuidedBaselineStatus(
      patientId: (json['patient_id'] ?? 'polar_h10').toString(),
      status: (json['status'] ?? 'not_ready').toString(),
      dayCount: _int(json['day_count']),
      targetDays: _int(json['target_days'], fallback: 7),
      progressRatio: _num(json['progress_ratio']),
      segmentPlan: ((json['segment_plan'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GuidedBaselineSegmentPlan.fromJson)
          .toList(),
      latestSession: json['latest_session'] is Map<String, dynamic>
          ? GuidedBaselineSession.fromJson(
              json['latest_session'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  String get statusText {
    switch (status.toLowerCase()) {
      case 'ready':
        return 'Da du 7 ngay baseline';
      case 'warming_up':
        return 'Dang hieu chinh tam thoi';
      default:
        return 'Chua du du lieu baseline';
    }
  }

  String get progressText =>
      'Ngay $dayCount/$targetDays - ${(progressRatio.clamp(0, 1) * 100).round()}%';
}

class GuidedBaselineSegmentPlan {
  final String segmentType;
  final String expectedActivity;
  final int durationSeconds;
  final String instruction;
  final bool skippable;

  const GuidedBaselineSegmentPlan({
    required this.segmentType,
    required this.expectedActivity,
    required this.durationSeconds,
    required this.instruction,
    required this.skippable,
  });

  factory GuidedBaselineSegmentPlan.fromJson(Map<String, dynamic> json) {
    return GuidedBaselineSegmentPlan(
      segmentType: (json['segment_type'] ?? '').toString(),
      expectedActivity: (json['expected_activity'] ?? '').toString(),
      durationSeconds: _int(json['duration_seconds']),
      instruction: (json['instruction'] ?? '').toString(),
      skippable: json['skippable'] as bool? ?? false,
    );
  }

  String get title {
    switch (segmentType.toUpperCase()) {
      case 'REST':
        return 'Nghi yen';
      case 'WALK':
        return 'Di bo cham';
      case 'ACTIVE':
        return 'Van dong nhe';
      default:
        return segmentType;
    }
  }

  String get userInstruction {
    switch (segmentType.toUpperCase()) {
      case 'REST':
        return 'Ngoi hoac nam yen, thu gian va giu day deo on dinh.';
      case 'WALK':
        return 'Di bo cham trong khu vuc an toan.';
      case 'ACTIVE':
        return 'Van dong nhe nhu sinh hoat binh thuong. Khong chay, khong nhay.';
      default:
        return instruction;
    }
  }
}

class GuidedBaselineSession {
  final String sessionId;
  final String status;
  final int dayIndex;
  final int targetDays;
  final List<GuidedBaselineSegment> segments;

  const GuidedBaselineSession({
    required this.sessionId,
    required this.status,
    required this.dayIndex,
    required this.targetDays,
    required this.segments,
  });

  factory GuidedBaselineSession.fromJson(Map<String, dynamic> json) {
    return GuidedBaselineSession(
      sessionId: (json['session_id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      dayIndex: _int(json['day_index']),
      targetDays: _int(json['target_days'], fallback: 7),
      segments: ((json['segments'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GuidedBaselineSegment.fromJson)
          .toList(),
    );
  }
}

class GuidedBaselineSegment {
  final String segmentType;
  final String status;
  final int durationSeconds;
  final int validWindowCount;
  final int rejectedWindowCount;
  final List<String> rejectionReasons;

  const GuidedBaselineSegment({
    required this.segmentType,
    required this.status,
    required this.durationSeconds,
    required this.validWindowCount,
    required this.rejectedWindowCount,
    required this.rejectionReasons,
  });

  factory GuidedBaselineSegment.fromJson(Map<String, dynamic> json) {
    return GuidedBaselineSegment(
      segmentType: (json['segment_type'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      durationSeconds: _int(json['duration_seconds']),
      validWindowCount: _int(json['valid_window_count']),
      rejectedWindowCount: _int(json['rejected_window_count']),
      rejectionReasons: ((json['rejection_reasons'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
