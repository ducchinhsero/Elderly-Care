import 'dart:convert';

/// Model dữ liệu vitals — parse từ MQTT topic ecg/vitals và GET /api/health
class VitalsModel {
  final DateTime timestamp;
  final String status;
  final double hrBpm;
  final double rmssdMs;
  final double lfHfRatio;
  final double anomalyScore;
  final String alertLevel;
  final String rawAlertLevel;
  final String? beatType;
  final String? beatName;
  final String activity;
  final String emotion;
  final double emotionConf;
  final List<ClinicalAlert> clinicalAlerts;
  final String rmssdNormal;
  final double latencyMs;

  const VitalsModel({
    required this.timestamp,
    required this.status,
    required this.hrBpm,
    required this.rmssdMs,
    required this.lfHfRatio,
    required this.anomalyScore,
    required this.alertLevel,
    required this.rawAlertLevel,
    this.beatType,
    this.beatName,
    required this.activity,
    required this.emotion,
    required this.emotionConf,
    required this.clinicalAlerts,
    required this.rmssdNormal,
    required this.latencyMs,
  });

  factory VitalsModel.fromJson(Map<String, dynamic> json) {
    return VitalsModel(
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String? ?? 'ok',
      hrBpm: (json['hr_bpm'] as num?)?.toDouble() ?? 0.0,
      rmssdMs: (json['rmssd_ms'] as num?)?.toDouble() ?? 0.0,
      lfHfRatio: (json['lf_hf_ratio'] as num?)?.toDouble() ?? 0.0,
      anomalyScore: (json['anomaly_score'] as num?)?.toDouble() ?? 0.0,
      alertLevel: json['alert_level'] as String? ?? 'SAFE',
      rawAlertLevel: json['raw_alert_level'] as String? ?? 'SAFE',
      beatType: json['beat_type'] as String?,
      beatName: json['beat_name'] as String?,
      activity: json['activity'] as String? ?? 'rest',
      emotion: json['emotion'] as String? ?? 'calm',
      emotionConf: (json['emotion_conf'] as num?)?.toDouble() ?? 0.0,
      clinicalAlerts: (json['clinical_alerts'] as List<dynamic>?)
              ?.map((e) => ClinicalAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rmssdNormal: json['rmssd_normal'] as String? ?? '',
      latencyMs: (json['latency_ms'] is Map)
          ? ((json['latency_ms'] as Map)['total'] as num?)?.toDouble() ?? 0.0
          : (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'hr_bpm': hrBpm,
      'rmssd_ms': rmssdMs,
      'lf_hf_ratio': lfHfRatio,
      'anomaly_score': anomalyScore,
      'alert_level': alertLevel,
      'raw_alert_level': rawAlertLevel,
      'beat_type': beatType,
      'beat_name': beatName,
      'activity': activity,
      'emotion': emotion,
      'emotion_conf': emotionConf,
      'clinical_alerts': clinicalAlerts.map((e) => e.toJson()).toList(),
      'rmssd_normal': rmssdNormal,
      'latency_ms': {'total': latencyMs},
    };
  }

  factory VitalsModel.fromMqttPayload(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return VitalsModel.fromJson(json);
  }

  /// Kiểm tra alert có cần cảnh báo không
  bool get isCritical => alertLevel.toUpperCase() == 'CRITICAL';
  bool get isAlert => alertLevel.toUpperCase() == 'ALERT';
  bool get isWatch => alertLevel.toUpperCase() == 'WATCH';
  bool get isSafe => alertLevel.toUpperCase() == 'SAFE';
  bool get needsAttention => !isSafe;

  /// Severity number cho sorting (cao hơn = nguy hiểm hơn)
  int get severityLevel {
    switch (alertLevel.toUpperCase()) {
      case 'CRITICAL':
        return 4;
      case 'ALERT':
        return 3;
      case 'WATCH':
        return 2;
      case 'SAFE':
        return 1;
      default:
        return 0;
    }
  }

  VitalsModel copyWith({
    DateTime? timestamp,
    String? status,
    double? hrBpm,
    double? rmssdMs,
    double? lfHfRatio,
    double? anomalyScore,
    String? alertLevel,
    String? rawAlertLevel,
    String? beatType,
    String? beatName,
    String? activity,
    String? emotion,
    double? emotionConf,
    List<ClinicalAlert>? clinicalAlerts,
    String? rmssdNormal,
    double? latencyMs,
  }) {
    return VitalsModel(
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      hrBpm: hrBpm ?? this.hrBpm,
      rmssdMs: rmssdMs ?? this.rmssdMs,
      lfHfRatio: lfHfRatio ?? this.lfHfRatio,
      anomalyScore: anomalyScore ?? this.anomalyScore,
      alertLevel: alertLevel ?? this.alertLevel,
      rawAlertLevel: rawAlertLevel ?? this.rawAlertLevel,
      beatType: beatType ?? this.beatType,
      beatName: beatName ?? this.beatName,
      activity: activity ?? this.activity,
      emotion: emotion ?? this.emotion,
      emotionConf: emotionConf ?? this.emotionConf,
      clinicalAlerts: clinicalAlerts ?? this.clinicalAlerts,
      rmssdNormal: rmssdNormal ?? this.rmssdNormal,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  @override
  String toString() =>
      'VitalsModel(hr=$hrBpm, rmssd=$rmssdMs, alert=$alertLevel, activity=$activity)';
}

/// Cảnh báo lâm sàng từ trường clinical_alerts
class ClinicalAlert {
  final String type;
  final String level;
  final String detail;

  const ClinicalAlert({
    required this.type,
    required this.level,
    required this.detail,
  });

  factory ClinicalAlert.fromJson(Map<String, dynamic> json) {
    return ClinicalAlert(
      type: json['type'] as String? ?? '',
      level: json['level'] as String? ?? 'WATCH',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'level': level,
      'detail': detail,
    };
  }
}
