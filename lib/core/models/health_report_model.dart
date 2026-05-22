class HealthReportModel {
  final String patientId;
  final String overallLevel;
  final String overallSummary;
  final HealthLayer realtime;
  final HealthLayer daily;
  final HealthLayer longTerm;
  final String disclaimer;

  const HealthReportModel({
    required this.patientId,
    required this.overallLevel,
    required this.overallSummary,
    required this.realtime,
    required this.daily,
    required this.longTerm,
    required this.disclaimer,
  });

  factory HealthReportModel.fromJson(Map<String, dynamic> json) {
    final layers = json['layers'] as Map<String, dynamic>? ?? const {};
    final overall = json['overall'] as Map<String, dynamic>? ?? const {};
    return HealthReportModel(
      patientId: (json['patient_id'] ?? '').toString(),
      overallLevel: (overall['level'] ?? 'unknown').toString(),
      overallSummary: (overall['summary'] ?? '').toString(),
      realtime: HealthLayer.fromJson(
        layers['realtime'] as Map<String, dynamic>? ?? const {},
        fallbackName: 'Realtime',
      ),
      daily: HealthLayer.fromJson(
        layers['daily'] as Map<String, dynamic>? ?? const {},
        fallbackName: '24h',
      ),
      longTerm: HealthLayer.fromJson(
        layers['long_term'] as Map<String, dynamic>? ?? const {},
        fallbackName: 'Long-term',
      ),
      disclaimer: (json['disclaimer'] ?? '').toString(),
    );
  }
}

class HealthLayer {
  final String title;
  final String level;
  final double score;
  final String summary;
  final String windowLabel;
  final List<HealthFinding> findings;

  const HealthLayer({
    required this.title,
    required this.level,
    required this.score,
    required this.summary,
    required this.windowLabel,
    required this.findings,
  });

  factory HealthLayer.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    final overall = json['overall'] as Map<String, dynamic>? ?? const {};
    final window = (json['window'] ?? json['period']) as Map<String, dynamic>? ?? const {};
    return HealthLayer(
      title: (json['title'] ?? fallbackName).toString(),
      level: (overall['level'] ?? 'unknown').toString(),
      score: _num(overall['score']),
      summary: (overall['summary'] ?? '').toString(),
      windowLabel: _windowLabel(window),
      findings: ((json['findings'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HealthFinding.fromJson)
          .toList(),
    );
  }
}

class HealthFinding {
  final String type;
  final String level;
  final String title;
  final String reason;
  final Map<String, dynamic> evidence;

  const HealthFinding({
    required this.type,
    required this.level,
    required this.title,
    required this.reason,
    required this.evidence,
  });

  factory HealthFinding.fromJson(Map<String, dynamic> json) {
    return HealthFinding(
      type: (json['type'] ?? '').toString(),
      level: (json['level'] ?? 'unknown').toString(),
      title: (json['title'] ?? json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      evidence: json['evidence'] as Map<String, dynamic>? ?? const {},
    );
  }
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

String _windowLabel(Map<String, dynamic> window) {
  final mode = (window['mode'] ?? '').toString();
  if (mode == 'latest_window') {
    return 'Cửa sổ mới nhất';
  }
  if (mode == 'rolling_24h') {
    return '${_num(window['hours']).toStringAsFixed(0)} giờ gần nhất';
  }
  if (mode == 'rolling_days') {
    final days = _num(window['days']).toStringAsFixed(0);
    final count = window['prediction_count'] ?? 0;
    return '$days ngày, $count lần đo';
  }
  return mode.isEmpty ? '--' : mode;
}
