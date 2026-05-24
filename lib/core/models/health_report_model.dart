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
    if (!calibrated) return 'Chua co muc nen ca nhan';
    switch (status.toLowerCase()) {
      case 'ready':
        return 'Da du 7 ngay';
      case 'warming_up':
        return 'Dang hieu chinh tam thoi';
      case 'not_ready':
        return 'Dang thu thap du lieu';
      default:
        return 'Dang hieu chinh';
    }
  }

  String get progressText {
    if (!calibrated) return 'Can thu thap du lieu trong cac ngay dau su dung.';
    return 'Ngay $dayCount/$targetDays'
        ' - ${(progressRatio.clamp(0, 1) * 100).round()}% tien do';
  }

  List<BaselineComparison> get comparisonRows {
    final rows = <BaselineComparison>[
      BaselineComparison.fromValue(
        label: 'HR trung binh',
        unit: 'bpm',
        value: comparisons['mean_hr_delta_bpm'],
      ),
      BaselineComparison.fromValue(
        label: 'HR khi nghi',
        unit: 'bpm',
        value: comparisons['resting_hr_delta_bpm'],
      ),
      BaselineComparison.fromRatio(
        label: 'AF suspicion',
        value: comparisons['af_suspicion_ratio_delta'],
      ),
      BaselineComparison.fromRatio(
        label: 'PVC/PAC',
        value: comparisons['ectopy_ratio_delta'],
      ),
      BaselineComparison.fromRatio(
        label: 'Anomaly',
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
    if (current == null) return 'Chua du du lieu';
    if (current.abs() < (isPercent ? 0.01 : 3.0)) {
      return 'Gan voi muc nen ca nhan';
    }
    if (current > 0) return 'Cao hon muc nen ca nhan';
    return 'Thap hon muc nen ca nhan';
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
  switch (level.toLowerCase()) {
    case 'critical':
      return 'Can ho tro ngay';
    case 'high':
      return 'Nen trao doi voi nhan vien y te';
    case 'medium':
      return 'Can theo doi';
    case 'low':
    case 'normal':
      return 'On dinh';
    default:
      return 'Chua du du lieu';
  }
}

String healthActionText(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return 'Kiem tra nguoi dung ngay va lien he cap cuu/nhan vien y te neu co trieu chung bat thuong.';
    case 'high':
      return 'Nen ghi nhan trieu chung va trao doi voi nhan vien y te, dac biet neu tinh trang lap lai.';
    case 'medium':
      return 'Tiep tuc theo doi. Neu co met, dau nguc, kho tho, choang vang hoac bat thuong lap lai, nen di kham.';
    case 'low':
    case 'normal':
      return 'Tiep tuc theo doi dinh ky va duy tri lich su do.';
    default:
      return 'Can thu thap them du lieu ECG tot truoc khi dua ra nhan dinh.';
  }
}

String findingTitle(String type, {required String fallback}) {
  final key = type.toLowerCase();
  if (key.contains('afib') || key.contains('af_suspicion')) {
    return 'Nghi ngo rung nhi/roi loan nhip';
  }
  if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
    return 'Hoat dong PVC/PAC bat thuong';
  }
  if (key.contains('heart_rate') ||
      key.contains('tachy') ||
      key.contains('brady')) {
    return 'Nhip tim nhanh/cham bat thuong';
  }
  if (key.contains('fall')) return 'Nghi ngo te nga';
  if (key.contains('poor_signal') || key.contains('signal_quality')) {
    return 'Chat luong tin hieu kem';
  }
  if (key.contains('anomaly')) return 'Xu huong ECG bat thuong';
  return fallback.isEmpty ? type : fallback;
}

String findingActionText(String type, String level) {
  final key = type.toLowerCase();
  if (key.contains('fall')) {
    return 'Kiem tra nguoi dung ngay va xac nhan co te nga hay khong.';
  }
  if (key.contains('poor_signal') || key.contains('signal_quality')) {
    return 'Kiem tra day deo, tiep xuc dien cuc va thu lai truoc khi ket luan.';
  }
  if (key.contains('afib') || key.contains('af_suspicion')) {
    return 'Neu ket qua lap lai hoac co hoi hop, met, kho tho, choang vang, nen trao doi voi nhan vien y te.';
  }
  if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
    return 'Theo doi tan suat. Neu tang len so voi muc nen hoac co trieu chung, nen di kham tim mach.';
  }
  if (key.contains('heart_rate') ||
      key.contains('tachy') ||
      key.contains('brady')) {
    return 'Kiem tra boi canh van dong/nghi ngoi. Neu nhip bat thuong keo dai, nen lien he nhan vien y te.';
  }
  if (key.contains('anomaly')) {
    return 'Nen xem lai lich su do va trao doi voi nhan vien y te neu bat thuong lap lai.';
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
  if (mode == 'latest_window') return 'Cua so moi nhat';
  if (mode == 'rolling_24h') {
    return '${_num(window['hours']).toStringAsFixed(0)} gio gan nhat';
  }
  if (mode == 'rolling_days') {
    final days = _num(window['days']).toStringAsFixed(0);
    final count = window['prediction_count'] ?? 0;
    return '$days ngay, $count lan do';
  }
  return mode.isEmpty ? '--' : mode;
}
