import 'dart:convert';

import '../utils/health_display_mapper.dart';

class VitalsModel {
  final DateTime timestamp;
  final String patientId;
  final String status;
  final int windowCount;
  final double hrBpm;
  final double rmssdMs;
  final double lfHfRatio;
  final double anomalyScore;
  final String anomalyLabel;
  final String alertLevel;
  final String rawAlertLevel;
  final String? beatType;
  final String? beatName;
  final String activity;
  final String stressLabel;
  final double stressConfidence;
  final double stressProbability;
  final String stressReason;
  final String emotion;
  final double emotionConf;
  final String rhythmLabel;
  final double rhythmConfidence;
  final double afibProbability;
  final String ectopyLabel;
  final double pvcProbability;
  final double pacProbability;
  final String signalQualityLabel;
  final double signalQualityScore;
  final String riskLevel;
  final double riskScore;
  final String riskReason;
  final String message;
  final List<ClinicalAlert> clinicalAlerts;
  final String rmssdNormal;
  final double latencyMs;
  // Backend contract additions.
  final bool hasHr; // false when backend heart_rate_bpm is null (poor signal)
  final List<String> signalQualityReasons;
  final double afBurdenPercent;
  final bool afEpisodeActive;
  final double afCurrentEpisodeSec;
  final int afEpisodeCount;
  final String hrEventLabel;

  const VitalsModel({
    required this.timestamp,
    required this.patientId,
    required this.status,
    required this.windowCount,
    required this.hrBpm,
    required this.rmssdMs,
    required this.lfHfRatio,
    required this.anomalyScore,
    required this.anomalyLabel,
    required this.alertLevel,
    required this.rawAlertLevel,
    this.beatType,
    this.beatName,
    required this.activity,
    required this.stressLabel,
    required this.stressConfidence,
    required this.stressProbability,
    required this.stressReason,
    required this.emotion,
    required this.emotionConf,
    required this.rhythmLabel,
    required this.rhythmConfidence,
    required this.afibProbability,
    required this.ectopyLabel,
    required this.pvcProbability,
    required this.pacProbability,
    required this.signalQualityLabel,
    required this.signalQualityScore,
    required this.riskLevel,
    required this.riskScore,
    required this.riskReason,
    required this.message,
    required this.clinicalAlerts,
    required this.rmssdNormal,
    required this.latencyMs,
    this.hasHr = false,
    this.signalQualityReasons = const [],
    this.afBurdenPercent = 0.0,
    this.afEpisodeActive = false,
    this.afCurrentEpisodeSec = 0.0,
    this.afEpisodeCount = 0,
    this.hrEventLabel = 'normal_hr',
  });

  factory VitalsModel.fromJson(Map<String, dynamic> json) {
    final latest = (json['latest_result'] as Map<String, dynamic>?) ?? json;
    final rhythm = latest['rhythm'] as Map<String, dynamic>? ?? const {};
    final rhythmAlert =
        latest['rhythm_alert'] as Map<String, dynamic>? ?? const {};
    final anomaly = latest['anomaly'] as Map<String, dynamic>? ?? const {};
    final stress = latest['stress'] as Map<String, dynamic>? ?? const {};
    final emotion = latest['emotion'] as Map<String, dynamic>? ?? const {};
    final ectopy = latest['ectopy'] as Map<String, dynamic>? ?? const {};
    final quality =
        latest['signal_quality'] as Map<String, dynamic>? ?? const {};
    final risk = latest['risk'] as Map<String, dynamic>? ?? const {};
    final sensor =
        latest['sensor_context'] as Map<String, dynamic>? ?? const {};
    final activityFeatures =
        sensor['activity_features'] as Map<String, dynamic>? ?? const {};
    final hrEvent = latest['hr_event'] as Map<String, dynamic>? ?? const {};
    final fall = sensor['fall'] as Map<String, dynamic>? ?? const {};
    final afEpisode =
        latest['af_episode'] as Map<String, dynamic>? ?? const {};
    final hrRaw = latest['heart_rate_bpm'] ?? latest['hr_bpm'];
    final qualityReasons = (quality['reasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final rhythmLabel =
        _str(rhythm['label'], fallback: latest['beat_type'] ?? 'unknown');
    final ectopyLabel = _str(ectopy['label'], fallback: 'unknown');
    final anomalyLabel = _str(anomaly['label'], fallback: 'unknown');
    final pipelineAlert = _str(latest['alert_level'], fallback: 'normal');
    final mappedAlert = _mapAlertLevel(pipelineAlert, rhythmAlert, risk, fall);
    final afibProbability = _num(
      rhythm['possible_afib_probability'] ??
          (rhythm['probabilities'] as Map<String, dynamic>?)?['possible_afib'],
    );
    final anomalyScore = anomaly['value'] == 1
        ? 1.0
        : _num(anomaly['score'] ?? anomaly['abnormal_ratio']);
    final clinicalAlerts = _clinicalAlertsFromJson(
      latest,
      mappedAlert,
      rhythmLabel,
      afibProbability,
      ectopyLabel,
      anomalyLabel,
      hrEvent,
      fall,
      rhythmAlert,
    );
    final stressLabel = _str(
      stress['label'] ??
          emotion['label'] ??
          latest['stress'] ??
          latest['emotion'],
      fallback: 'unknown',
    );
    final stressConfidence = _num(
      stress['confidence'] ??
          emotion['confidence'] ??
          latest['stress_confidence'] ??
          latest['emotion_confidence'] ??
          latest['emotion_conf'],
    );
    final stressProbability = _num(
      (stress['probabilities'] as Map<String, dynamic>?)?['stress'] ??
          (emotion['probabilities'] as Map<String, dynamic>?)?['stress'] ??
          (stressLabel == 'stress' ? stressConfidence : 0.0),
    );

    return VitalsModel(
      timestamp: _date(latest['timestamp']),
      patientId: _str(latest['patient_id'], fallback: 'unknown'),
      status: _str(latest['status'], fallback: 'ok'),
      windowCount: _int(latest['window_count']),
      hrBpm: _num(latest['heart_rate_bpm'] ?? latest['hr_bpm']),
      rmssdMs: _rmssdFromLatest(latest, sensor),
      lfHfRatio: _num(latest['lf_hf_ratio']),
      anomalyScore: anomalyScore,
      anomalyLabel: anomalyLabel,
      alertLevel: mappedAlert,
      rawAlertLevel: pipelineAlert,
      beatType: _conditionKey(rhythmLabel, ectopyLabel, hrEvent),
      beatName: _conditionName(rhythmLabel, ectopyLabel, afibProbability),
      activity: _str(sensor['activity_state'] ?? latest['activity'],
          fallback: 'REST'),
      stressLabel: stressLabel,
      stressConfidence: stressConfidence,
      stressProbability: stressProbability,
      stressReason: _str(stress['reason'], fallback: ''),
      emotion: _mapStressToLegacyEmotion(stressLabel),
      emotionConf: stressConfidence,
      rhythmLabel: rhythmLabel,
      rhythmConfidence: _num(rhythm['confidence'] ?? rhythm['probability']),
      afibProbability: afibProbability,
      ectopyLabel: ectopyLabel,
      pvcProbability: _num(ectopy['pvc_probability']),
      pacProbability: _num(ectopy['pac_probability']),
      signalQualityLabel: _str(quality['label'], fallback: 'unknown'),
      signalQualityScore: _num(quality['score']),
      riskLevel: _str(risk['level'], fallback: 'unknown'),
      riskScore: _num(risk['score']),
      riskReason: _str(risk['reason'], fallback: ''),
      message: _str(latest['message'],
          fallback: _summaryMessage(mappedAlert, clinicalAlerts)),
      clinicalAlerts: clinicalAlerts,
      rmssdNormal: _qualitySummary(quality, activityFeatures),
      latencyMs: _num(latest['latency_ms'] is Map
          ? (latest['latency_ms'] as Map)['total']
          : latest['latency_ms']),
      hasHr: hrRaw != null,
      signalQualityReasons: qualityReasons,
      afBurdenPercent: _num(afEpisode['af_burden_percent']),
      afEpisodeActive: afEpisode['active'] == true,
      afCurrentEpisodeSec: _num(afEpisode['current_episode_duration_sec']),
      afEpisodeCount: _int(afEpisode['af_episode_count']),
      hrEventLabel: _str(hrEvent['label'], fallback: 'normal_hr'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'patient_id': patientId,
      'status': status,
      'window_count': windowCount,
      'hr_bpm': hrBpm,
      'rmssd_ms': rmssdMs,
      'lf_hf_ratio': lfHfRatio,
      'anomaly_score': anomalyScore,
      'anomaly_label': anomalyLabel,
      'alert_level': alertLevel,
      'raw_alert_level': rawAlertLevel,
      'beat_type': beatType,
      'beat_name': beatName,
      'activity': activity,
      'stress': {
        'label': stressLabel,
        'confidence': stressConfidence,
        'reason': stressReason,
        'probabilities': {'stress': stressProbability},
      },
      'emotion': emotion,
      'emotion_conf': emotionConf,
      'rhythm_label': rhythmLabel,
      'rhythm_confidence': rhythmConfidence,
      'afib_probability': afibProbability,
      'ectopy_label': ectopyLabel,
      'pvc_probability': pvcProbability,
      'pac_probability': pacProbability,
      'signal_quality': signalQualityLabel,
      'signal_quality_score': signalQualityScore,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'risk_reason': riskReason,
      'message': message,
      'clinical_alerts': clinicalAlerts.map((e) => e.toJson()).toList(),
      'rmssd_normal': rmssdNormal,
      'latency_ms': {'total': latencyMs},
    };
  }

  factory VitalsModel.fromMqttPayload(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return VitalsModel.fromJson(json);
  }

  bool get isCritical => alertLevel.toUpperCase() == 'CRITICAL';
  bool get isAlert => alertLevel.toUpperCase() == 'ALERT';
  bool get isWatch => alertLevel.toUpperCase() == 'WATCH';
  bool get isSafe => alertLevel.toUpperCase() == 'SAFE';
  bool get needsAttention => !isSafe;
  bool get hasReliableSignal =>
      signalQualityLabel == 'good' || signalQualityLabel == 'fair';

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
    String? patientId,
    String? status,
    int? windowCount,
    double? hrBpm,
    double? rmssdMs,
    double? lfHfRatio,
    double? anomalyScore,
    String? anomalyLabel,
    String? alertLevel,
    String? rawAlertLevel,
    String? beatType,
    String? beatName,
    String? activity,
    String? stressLabel,
    double? stressConfidence,
    double? stressProbability,
    String? stressReason,
    String? emotion,
    double? emotionConf,
    String? rhythmLabel,
    double? rhythmConfidence,
    double? afibProbability,
    String? ectopyLabel,
    double? pvcProbability,
    double? pacProbability,
    String? signalQualityLabel,
    double? signalQualityScore,
    String? riskLevel,
    double? riskScore,
    String? riskReason,
    String? message,
    List<ClinicalAlert>? clinicalAlerts,
    String? rmssdNormal,
    double? latencyMs,
    bool? hasHr,
    List<String>? signalQualityReasons,
    double? afBurdenPercent,
    bool? afEpisodeActive,
    double? afCurrentEpisodeSec,
    int? afEpisodeCount,
    String? hrEventLabel,
  }) {
    return VitalsModel(
      timestamp: timestamp ?? this.timestamp,
      patientId: patientId ?? this.patientId,
      status: status ?? this.status,
      windowCount: windowCount ?? this.windowCount,
      hrBpm: hrBpm ?? this.hrBpm,
      rmssdMs: rmssdMs ?? this.rmssdMs,
      lfHfRatio: lfHfRatio ?? this.lfHfRatio,
      anomalyScore: anomalyScore ?? this.anomalyScore,
      anomalyLabel: anomalyLabel ?? this.anomalyLabel,
      alertLevel: alertLevel ?? this.alertLevel,
      rawAlertLevel: rawAlertLevel ?? this.rawAlertLevel,
      beatType: beatType ?? this.beatType,
      beatName: beatName ?? this.beatName,
      activity: activity ?? this.activity,
      stressLabel: stressLabel ?? this.stressLabel,
      stressConfidence: stressConfidence ?? this.stressConfidence,
      stressProbability: stressProbability ?? this.stressProbability,
      stressReason: stressReason ?? this.stressReason,
      emotion: emotion ?? this.emotion,
      emotionConf: emotionConf ?? this.emotionConf,
      rhythmLabel: rhythmLabel ?? this.rhythmLabel,
      rhythmConfidence: rhythmConfidence ?? this.rhythmConfidence,
      afibProbability: afibProbability ?? this.afibProbability,
      ectopyLabel: ectopyLabel ?? this.ectopyLabel,
      pvcProbability: pvcProbability ?? this.pvcProbability,
      pacProbability: pacProbability ?? this.pacProbability,
      signalQualityLabel: signalQualityLabel ?? this.signalQualityLabel,
      signalQualityScore: signalQualityScore ?? this.signalQualityScore,
      riskLevel: riskLevel ?? this.riskLevel,
      riskScore: riskScore ?? this.riskScore,
      riskReason: riskReason ?? this.riskReason,
      message: message ?? this.message,
      clinicalAlerts: clinicalAlerts ?? this.clinicalAlerts,
      rmssdNormal: rmssdNormal ?? this.rmssdNormal,
      latencyMs: latencyMs ?? this.latencyMs,
      hasHr: hasHr ?? this.hasHr,
      signalQualityReasons: signalQualityReasons ?? this.signalQualityReasons,
      afBurdenPercent: afBurdenPercent ?? this.afBurdenPercent,
      afEpisodeActive: afEpisodeActive ?? this.afEpisodeActive,
      afCurrentEpisodeSec: afCurrentEpisodeSec ?? this.afCurrentEpisodeSec,
      afEpisodeCount: afEpisodeCount ?? this.afEpisodeCount,
      hrEventLabel: hrEventLabel ?? this.hrEventLabel,
    );
  }

  /// HR text for display — "--" when the backend could not measure HR.
  String get hrText => hasHr ? hrBpm.toStringAsFixed(0) : '--';

  /// Stress model is still filling its 5-minute rolling RR window.
  bool get stressIsWarmingUp =>
      stressLabel.toLowerCase() == 'unknown' &&
      stressReason.toLowerCase().contains('warming');
}

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
      type: _str(json['type'] ?? json['event_type'], fallback: 'UNKNOWN'),
      level: _mapAlertLevel(
          _str(json['level'] ?? json['severity'], fallback: 'WATCH'),
          const {},
          const {},
          const {}),
      detail: _str(json['detail'] ?? json['message'] ?? json['label'],
          fallback: ''),
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

double _num(dynamic value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _str(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

DateTime _date(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String _mapAlertLevel(
  String value,
  Map<String, dynamic> rhythmAlert,
  Map<String, dynamic> risk,
  Map<String, dynamic> fall,
) {
  if (fall['strong_fall'] == true) return 'CRITICAL';
  if (fall['fall_candidate'] == true) return 'ALERT';
  final raw = value.toLowerCase();
  if (raw == 'critical') return 'CRITICAL';
  if (raw == 'high' || raw == 'alert') return 'ALERT';
  if (raw == 'medium' || raw == 'watch' || raw == 'unknown') return 'WATCH';
  if (raw == 'normal' || raw == 'low' || raw == 'safe' || raw == 'clear') {
    return 'SAFE';
  }

  final rhythmLevel = _str(rhythmAlert['level']).toLowerCase();
  final riskLevel = _str(risk['level']).toLowerCase();
  if (rhythmLevel == 'critical' || riskLevel == 'critical') return 'CRITICAL';
  if (rhythmLevel == 'high' || riskLevel == 'high') return 'ALERT';
  if (rhythmLevel == 'medium' || riskLevel == 'medium') return 'WATCH';
  return 'SAFE';
}

double _rmssdFromLatest(
  Map<String, dynamic> latest,
  Map<String, dynamic> sensor,
) {
  final hrv = latest['hrv'] as Map<String, dynamic>? ?? const {};
  final hrvMetrics = latest['hrv_metrics'] as Map<String, dynamic>? ?? const {};
  final features = latest['features'] as Map<String, dynamic>? ?? const {};
  final metrics = latest['metrics'] as Map<String, dynamic>? ?? const {};
  final sensorHrv = sensor['hrv'] as Map<String, dynamic>? ?? const {};

  for (final value in [
    latest['rmssd_ms'],
    latest['rmssd'],
    hrv['rmssd_ms'],
    hrv['rmssd'],
    hrvMetrics['rmssd_ms'],
    hrvMetrics['rmssd'],
    features['rmssd_ms'],
    features['rmssd'],
    metrics['rmssd_ms'],
    metrics['rmssd'],
    sensorHrv['rmssd_ms'],
    sensorHrv['rmssd'],
  ]) {
    final parsed = _num(value, fallback: -1);
    if (parsed > 0) return parsed;
  }
  return 0.0;
}

String _mapStressToLegacyEmotion(String value) {
  switch (value.toLowerCase()) {
    case 'non_stress':
      return 'calm';
    case 'stress':
      return 'stressed';
    default:
      return 'unknown';
  }
}

String _conditionKey(
    String rhythmLabel, String ectopyLabel, Map<String, dynamic> hrEvent) {
  if (rhythmLabel == 'possible_afib') return 'AF_NEW';
  if (ectopyLabel == 'pvc' || ectopyLabel == 'mixed_ectopic')
    return 'PVC_ISOLATED';
  if (_str(hrEvent['label']).contains('tachycardia')) return 'ST_PATHOLOGICAL';
  if (_str(hrEvent['label']).contains('bradycardia')) return 'SB_PATHOLOGICAL';
  return 'NSR';
}

String _conditionName(
    String rhythmLabel, String ectopyLabel, double afibProbability) {
  if (rhythmLabel == 'possible_afib') {
    return 'Có dấu hiệu nhịp tim không đều';
  }
  if (rhythmLabel == 'other_rhythm') return 'Nhịp tim cần theo dõi thêm';
  if (ectopyLabel == 'pvc') return 'Có nhịp đến sớm';
  if (ectopyLabel == 'pac') return 'Có nhịp đến sớm';
  if (ectopyLabel == 'mixed_ectopic') return 'Có nhịp đến sớm';
  if (rhythmLabel == 'normal') return 'Nhịp tim đang đều';
  return 'Đang phân tích nhịp tim';
}

String _qualitySummary(
    Map<String, dynamic> quality, Map<String, dynamic> activityFeatures) {
  final label = _str(quality['label'], fallback: 'unknown');
  final score = (_num(quality['score']) * 100).round();
  final accStd = activityFeatures['acc_vm_std'];
  final movement =
      accStd == null ? '' : ' | vận động ${_num(accStd).toStringAsFixed(1)} mG';
  return '${HealthDisplayMapper.signalLabel(label)}, độ tin cậy $score%$movement';
}

String _summaryMessage(String alertLevel, List<ClinicalAlert> alerts) {
  if (alerts.isNotEmpty) return alerts.first.detail;
  if (alertLevel == 'SAFE') return 'Các chỉ số hiện tại ổn định.';
  return 'Có tín hiệu cần theo dõi.';
}

List<ClinicalAlert> _clinicalAlertsFromJson(
  Map<String, dynamic> latest,
  String mappedAlert,
  String rhythmLabel,
  double afibProbability,
  String ectopyLabel,
  String anomalyLabel,
  Map<String, dynamic> hrEvent,
  Map<String, dynamic> fall,
  Map<String, dynamic> rhythmAlert,
) {
  final rawAlerts = latest['clinical_alerts'];
  final alerts = <ClinicalAlert>[];
  if (rawAlerts is List) {
    for (final item in rawAlerts) {
      if (item is Map<String, dynamic>) {
        alerts.add(ClinicalAlert.fromJson(item));
      } else if (item != null) {
        alerts.add(ClinicalAlert(
          type: item.toString(),
          level: mappedAlert,
          detail: item.toString(),
        ));
      }
    }
  }

  if (fall['strong_fall'] == true || fall['fall_candidate'] == true) {
    alerts.add(ClinicalAlert(
      type: 'fall_candidate',
      level: fall['strong_fall'] == true ? 'CRITICAL' : 'ALERT',
      detail: 'Phát hiện khả năng té ngã. Cần kiểm tra ngay.',
    ));
  }
  if (rhythmLabel == 'possible_afib' || afibProbability >= 0.28) {
    alerts.add(ClinicalAlert(
      type: 'afib_suspicion',
      level: afibProbability >= 0.5 ||
              _str(rhythmAlert['level']).toLowerCase() == 'high'
          ? 'ALERT'
          : 'WATCH',
      detail: _str(
        rhythmAlert['message'],
        fallback:
            'Khoảng đo gần đây có dấu hiệu nhịp tim không đều. Nên tiếp tục theo dõi.',
      ),
    ));
  }
  if (ectopyLabel == 'pvc' ||
      ectopyLabel == 'pac' ||
      ectopyLabel == 'mixed_ectopic') {
    alerts.add(ClinicalAlert(
      type: 'ectopy_suspicion',
      level: 'WATCH',
      detail: 'Có dấu hiệu nhịp đến sớm trong cửa sổ đo gần nhất.',
    ));
  }
  if (_str(hrEvent['label']).contains('tachycardia') ||
      _str(hrEvent['label']).contains('bradycardia')) {
    alerts.add(ClinicalAlert(
      type: _str(hrEvent['label'], fallback: 'heart_rate_event'),
      level: mappedAlert == 'SAFE' ? 'WATCH' : mappedAlert,
      detail: _str(hrEvent['message'],
          fallback: 'Nhịp tim nằm ngoài mức thường thấy theo bối cảnh.'),
    ));
  }
  if (anomalyLabel == 'abnormal') {
    alerts.add(const ClinicalAlert(
      type: 'ecg_anomaly',
      level: 'WATCH',
      detail:
          'Có tín hiệu ECG bất thường sơ bộ. Cần kiểm tra chất lượng dây đeo và theo dõi nếu lặp lại.',
    ));
  }
  return alerts;
}
