/// Model dữ liệu lịch sử — từ GET /api/history?hours=24
class HistoryModel {
  final List<HistoryPoint> points;
  final HistoryStats? stats;

  const HistoryModel({
    required this.points,
    this.stats,
  });

  factory HistoryModel.fromJson(dynamic json) {
    List<HistoryPoint> points;

    if (json is List) {
      points = json
          .map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json is Map<String, dynamic>) {
      points = ((json['data'] ?? json['items']) as List<dynamic>?)
              ?.map((e) => HistoryPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } else {
      points = [];
    }

    // Sort by timestamp ascending
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return HistoryModel(
      points: points,
      stats: points.isNotEmpty ? HistoryStats.calculate(points) : null,
    );
  }

  /// Lọc theo khoảng thời gian
  HistoryModel filterByDateRange(DateTime start, DateTime end) {
    final filtered = points
        .where((p) => p.timestamp.isAfter(start) && p.timestamp.isBefore(end))
        .toList();
    return HistoryModel(
      points: filtered,
      stats: filtered.isNotEmpty ? HistoryStats.calculate(filtered) : null,
    );
  }

  bool get isEmpty => points.isEmpty;
  int get length => points.length;
}

/// Một điểm dữ liệu trong lịch sử
class HistoryPoint {
  final DateTime timestamp;
  final double hrBpm;
  final double rmssdMs;
  final double lfHfRatio;
  final double anomalyScore;
  final String alertLevel;
  final String activity;
  final String stressLabel;
  final double stressConf;
  final String emotion;
  final double emotionConf;

  const HistoryPoint({
    required this.timestamp,
    required this.hrBpm,
    required this.rmssdMs,
    required this.lfHfRatio,
    required this.anomalyScore,
    required this.alertLevel,
    required this.activity,
    required this.stressLabel,
    required this.stressConf,
    required this.emotion,
    required this.emotionConf,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    final stress = json['stress'] as Map<String, dynamic>?;
    final emotion = json['emotion'] as Map<String, dynamic>?;
    final anomaly = json['anomaly'] as Map<String, dynamic>?;
    final risk = json['risk'] as Map<String, dynamic>?;
    final sensor = json['sensor_context'] as Map<String, dynamic>?;
    return HistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      hrBpm: (json['heart_rate_bpm'] as num?)?.toDouble() ??
          (json['hr_bpm'] as num?)?.toDouble() ??
          0.0,
      rmssdMs: (json['rmssd_ms'] as num?)?.toDouble() ?? 0.0,
      lfHfRatio: (json['lf_hf_ratio'] as num?)?.toDouble() ?? 0.0,
      anomalyScore: (json['anomaly_score'] as num?)?.toDouble() ??
          ((anomaly?['value'] == 1) ? 1.0 : 0.0),
      alertLevel: _mapAlertLevel(json['alert_level'] as String? ??
          risk?['level'] as String? ??
          'SAFE'),
      activity: sensor?['activity_state'] as String? ??
          json['activity'] as String? ??
          'rest',
      stressLabel: _mapStress(stress?['label'] as String? ??
          emotion?['label'] as String? ??
          json['stress'] as String? ??
          json['emotion'] as String? ??
          'unknown'),
      stressConf: (stress?['confidence'] as num?)?.toDouble() ??
          (emotion?['confidence'] as num?)?.toDouble() ??
          (json['stress_conf'] as num?)?.toDouble() ??
          (json['emotion_conf'] as num?)?.toDouble() ??
          0.0,
      emotion: _mapStressToLegacyEmotion(stress?['label'] as String? ??
          emotion?['label'] as String? ??
          json['stress'] as String? ??
          json['emotion'] as String? ??
          'unknown'),
      emotionConf: (stress?['confidence'] as num?)?.toDouble() ??
          (emotion?['confidence'] as num?)?.toDouble() ??
          (json['stress_conf'] as num?)?.toDouble() ??
          (json['emotion_conf'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'hr_bpm': hrBpm,
      'rmssd_ms': rmssdMs,
      'lf_hf_ratio': lfHfRatio,
      'anomaly_score': anomalyScore,
      'alert_level': alertLevel,
      'activity': activity,
      'stress': {'label': stressLabel, 'confidence': stressConf},
      'emotion': emotion,
      'emotion_conf': emotionConf,
    };
  }

  bool get hasAlert => alertLevel.toUpperCase() != 'SAFE';
}

String _mapAlertLevel(String raw) {
  switch (raw.toLowerCase()) {
    case 'critical':
      return 'CRITICAL';
    case 'high':
    case 'alert':
      return 'ALERT';
    case 'medium':
    case 'watch':
    case 'unknown':
      return 'WATCH';
    case 'normal':
    case 'low':
    case 'safe':
    default:
      return 'SAFE';
  }
}

String _mapStress(String raw) {
  switch (raw.toLowerCase()) {
    case 'stress':
      return 'stress';
    case 'non_stress':
    case 'neutral':
    case 'relaxed':
    case 'calm':
    case 'positive':
      return 'non_stress';
    default:
      return 'unknown';
  }
}

String _mapStressToLegacyEmotion(String raw) {
  switch (raw.toLowerCase()) {
    case 'neutral':
    case 'non_stress':
      return 'calm';
    case 'relaxed':
      return 'positive';
    case 'stress':
      return 'stressed';
    default:
      return raw;
  }
}

/// Thống kê từ dữ liệu lịch sử
class HistoryStats {
  final double hrAvg;
  final double hrMin;
  final double hrMax;
  final double rmssdAvg;
  final double rmssdMin;
  final double rmssdMax;
  final double normalPercent; // % thời gian trong ngưỡng
  final int alertCount;
  final Map<String, double> activityDistribution; // activity -> % time
  final Map<String, double> stressDistribution; // stress -> % time
  final Map<String, double> emotionDistribution; // emotion -> % time

  const HistoryStats({
    required this.hrAvg,
    required this.hrMin,
    required this.hrMax,
    required this.rmssdAvg,
    required this.rmssdMin,
    required this.rmssdMax,
    required this.normalPercent,
    required this.alertCount,
    required this.activityDistribution,
    required this.stressDistribution,
    required this.emotionDistribution,
  });

  /// Tính thống kê từ danh sách data points
  factory HistoryStats.calculate(List<HistoryPoint> points) {
    if (points.isEmpty) {
      return const HistoryStats(
        hrAvg: 0,
        hrMin: 0,
        hrMax: 0,
        rmssdAvg: 0,
        rmssdMin: 0,
        rmssdMax: 0,
        normalPercent: 0,
        alertCount: 0,
        activityDistribution: {},
        stressDistribution: {},
        emotionDistribution: {},
      );
    }

    double hrSum = 0, rmssdSum = 0;
    double hrMin = double.infinity, hrMax = double.negativeInfinity;
    double rmssdMin = double.infinity, rmssdMax = double.negativeInfinity;
    int safeCount = 0;
    int alertCount = 0;
    final activityCount = <String, int>{};
    final stressCount = <String, int>{};
    final emotionCount = <String, int>{};

    for (final p in points) {
      hrSum += p.hrBpm;
      rmssdSum += p.rmssdMs;
      if (p.hrBpm < hrMin) hrMin = p.hrBpm;
      if (p.hrBpm > hrMax) hrMax = p.hrBpm;
      if (p.rmssdMs < rmssdMin) rmssdMin = p.rmssdMs;
      if (p.rmssdMs > rmssdMax) rmssdMax = p.rmssdMs;
      if (p.alertLevel.toUpperCase() == 'SAFE') safeCount++;
      if (p.hasAlert) alertCount++;
      activityCount[p.activity] = (activityCount[p.activity] ?? 0) + 1;
      stressCount[p.stressLabel] = (stressCount[p.stressLabel] ?? 0) + 1;
      emotionCount[p.emotion] = (emotionCount[p.emotion] ?? 0) + 1;
    }

    final total = points.length.toDouble();

    return HistoryStats(
      hrAvg: hrSum / total,
      hrMin: hrMin == double.infinity ? 0 : hrMin,
      hrMax: hrMax == double.negativeInfinity ? 0 : hrMax,
      rmssdAvg: rmssdSum / total,
      rmssdMin: rmssdMin == double.infinity ? 0 : rmssdMin,
      rmssdMax: rmssdMax == double.negativeInfinity ? 0 : rmssdMax,
      normalPercent: (safeCount / total) * 100,
      alertCount: alertCount,
      activityDistribution:
          activityCount.map((k, v) => MapEntry(k, (v / total) * 100)),
      stressDistribution:
          stressCount.map((k, v) => MapEntry(k, (v / total) * 100)),
      emotionDistribution:
          emotionCount.map((k, v) => MapEntry(k, (v / total) * 100)),
    );
  }
}
