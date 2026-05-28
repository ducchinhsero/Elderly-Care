import '../utils/health_display_mapper.dart';

class HealthReportModel {
  final String patientId;
  final String overallLevel;
  final String overallSummary;
  final HealthLayer realtime;
  final HealthLayer daily;
  final HealthLayer longTerm;
  final PersonalBaseline personalBaseline;
  final String disclaimer;

  const HealthReportModel({
    required this.patientId,
    required this.overallLevel,
    required this.overallSummary,
    required this.realtime,
    required this.daily,
    required this.longTerm,
    required this.personalBaseline,
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
      personalBaseline: PersonalBaseline.fromJson(
        json['personal_baseline'] as Map<String, dynamic>? ?? const {},
      ),
      disclaimer: (json['disclaimer'] ?? '').toString(),
    );
  }

  List<HealthFinding> get importantFindings {
    final items = <HealthFinding>[
      ...realtime.findings,
      ...daily.findings,
      ...longTerm.findings,
    ];
    items.sort((a, b) => b.severityRank.compareTo(a.severityRank));
    return items;
  }

  bool get hasFindings => importantFindings.isNotEmpty;

  String get userLevelText => healthLevelText(overallLevel);
  String get userActionText => healthActionText(overallLevel);
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
    final window =
        (json['window'] ?? json['period']) as Map<String, dynamic>? ?? const {};
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

  String get userLevelText => healthLevelText(level);
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

  int get severityRank => healthSeverityRank(level);
  String get userLevelText => healthLevelText(level);
  String get displayTitle => findingTitle(type, fallback: title);
  String get actionText => findingActionText(type, level);
}

class PersonalBaseline {
  final bool calibrated;
  final String status;
  final int dayCount;
  final int targetDays;
  final double progressRatio;
  final bool dataQualityOk;
  final String summary;
  final Map<String, dynamic> comparisons;

  const PersonalBaseline({
    required this.calibrated,
    required this.status,
    required this.dayCount,
    required this.targetDays,
    required this.progressRatio,
    required this.dataQualityOk,
    required this.summary,
    required this.comparisons,
  });

  factory PersonalBaseline.fromJson(Map<String, dynamic> json) {
    final calibration =
        json['calibration'] as Map<String, dynamic>? ?? const {};
    return PersonalBaseline(
      calibrated: json['calibrated'] as bool? ?? false,
      status: (calibration['status'] ?? 'not_calibrated').toString(),
      dayCount: _int(calibration['day_count']),
      targetDays: _int(calibration['target_days'], fallback: 7),
      progressRatio: _num(calibration['progress_ratio']),
      dataQualityOk: calibration['data_quality_ok'] as bool? ?? false,
      summary: (json['summary'] ?? '').toString(),
      comparisons: json['comparisons'] as Map<String, dynamic>? ?? const {},
    );
  }

  String get statusText {
    if (!calibrated) return 'Chưa có mức bình thường riêng';
    switch (status.toLowerCase()) {
      case 'ready':
        return 'Đã đủ dữ liệu so sánh';
      case 'warming_up':
        return 'Đang thiết lập tạm thời';
      case 'not_ready':
        return 'Đang thu thập dữ liệu';
      default:
        return 'Đang thiết lập';
    }
  }

  String get progressText {
    if (!calibrated)
      return 'Cần vài ngày dữ liệu tốt để so sánh chính xác hơn.';
    return 'Ngày $dayCount/$targetDays'
        ' - ${(progressRatio.clamp(0, 1) * 100).round()}% tiến độ';
  }

  List<BaselineComparison> get comparisonRows {
    final rows = <BaselineComparison>[
      BaselineComparison.fromValue(
        label: 'Nhịp tim trung bình',
        unit: 'bpm',
        value: comparisons['mean_hr_delta_bpm'],
      ),
      BaselineComparison.fromValue(
        label: 'Nhịp tim khi nghỉ',
        unit: 'bpm',
        value: comparisons['resting_hr_delta_bpm'],
      ),
      BaselineComparison.fromRatio(
        label: 'Nhịp tim không đều',
        value: comparisons['af_suspicion_ratio_delta'],
      ),
      BaselineComparison.fromRatio(
        label: 'Nhịp đến sớm',
        value: comparisons['ectopy_ratio_delta'],
      ),
      BaselineComparison.fromRatio(
        label: 'Điểm đo cần xem lại',
        value: comparisons['abnormal_ratio_delta'],
      ),
    ];
    return rows.where((row) => row.hasValue).toList();
  }
}

class BaselineComparison {
  final String label;
  final double? value;
  final String unit;
  final bool isPercent;

  const BaselineComparison({
    required this.label,
    required this.value,
    required this.unit,
    required this.isPercent,
  });

  factory BaselineComparison.fromValue({
    required String label,
    required String unit,
    required dynamic value,
  }) {
    return BaselineComparison(
      label: label,
      value: _nullableNum(value),
      unit: unit,
      isPercent: false,
    );
  }

  factory BaselineComparison.fromRatio({
    required String label,
    required dynamic value,
  }) {
    return BaselineComparison(
      label: label,
      value: _nullableNum(value),
      unit: '%',
      isPercent: true,
    );
  }

  bool get hasValue => value != null;

  String get displayValue {
    final current = value;
    if (current == null) return '--';
    final sign = current > 0 ? '+' : '';
    if (isPercent) return '$sign${(current * 100).toStringAsFixed(1)}%';
    return '$sign${current.toStringAsFixed(1)} $unit';
  }

  String get interpretation {
    final current = value;
    if (current == null) return 'Chưa đủ dữ liệu';
    if (current.abs() < (isPercent ? 0.01 : 3.0)) {
      return 'Gần với mức bình thường riêng';
    }
    if (current > 0) return 'Cao hơn mức bình thường riêng';
    return 'Thấp hơn mức bình thường riêng';
  }
}

int healthSeverityRank(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return 4;
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
    case 'normal':
      return 1;
    default:
      return 0;
  }
}

String healthLevelText(String level) {
  return HealthDisplayMapper.levelLabel(level);
}

String healthActionText(String level) {
  return HealthDisplayMapper.levelAction(level);
}

String findingTitle(String type, {required String fallback}) {
  final key = type.toLowerCase();
  if (key.contains('afib') || key.contains('af_suspicion')) {
    return 'Dấu hiệu nhịp tim không đều';
  }
  if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
    return 'Có nhiều nhịp đến sớm';
  }
  if (key.contains('heart_rate') ||
      key.contains('tachy') ||
      key.contains('brady')) {
    return 'Nhịp tim nhanh/chậm hơn bình thường';
  }
  if (key.contains('fall')) return 'Nghi ngờ té ngã';
  if (key.contains('poor_signal') || key.contains('signal_quality')) {
    return 'Tín hiệu đo chưa tốt';
  }
  if (key.contains('anomaly')) return 'Có điểm đo cần xem lại';
  return fallback.isEmpty ? type : fallback;
}

String findingActionText(String type, String level) {
  final key = type.toLowerCase();
  if (key.contains('fall')) {
    return 'Kiểm tra người dùng ngay và xác nhận có té ngã hay không.';
  }
  if (key.contains('poor_signal') || key.contains('signal_quality')) {
    return 'Chỉnh lại dây đeo/cảm biến rồi đo lại trước khi kết luận.';
  }
  if (key.contains('afib') || key.contains('af_suspicion')) {
    return 'Nếu kết quả lặp lại hoặc có hồi hộp, mệt, khó thở, choáng váng, nên trao đổi với nhân viên y tế.';
  }
  if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
    return 'Theo dõi tần suất. Nếu tăng lên so với mức bình thường riêng hoặc có triệu chứng, nên đi khám.';
  }
  if (key.contains('heart_rate') ||
      key.contains('tachy') ||
      key.contains('brady')) {
    return 'Kiểm tra người dùng đang nghỉ hay vận động. Nếu nhịp bất thường kéo dài, nên liên hệ nhân viên y tế.';
  }
  if (key.contains('anomaly')) {
    return 'Xem lại lịch sử đo và trao đổi với nhân viên y tế nếu bất thường lặp lại.';
  }
  return healthActionText(level);
}

double _num(dynamic value) => _nullableNum(value) ?? 0.0;

double? _nullableNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _windowLabel(Map<String, dynamic> window) {
  final mode = (window['mode'] ?? '').toString();
  if (mode == 'latest_window') return 'Lần đo gần nhất';
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
