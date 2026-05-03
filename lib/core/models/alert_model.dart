/// Model cho alert data — từ GET /api/alerts và MQTT ecg/alert
class AlertModel {
  final String id;
  final DateTime timestamp;
  final String type;
  final String level;
  final String detail;
  final double? hrBpm;
  final double? rmssdMs;
  final String? activity;
  final bool isRead;

  const AlertModel({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.level,
    required this.detail,
    this.hrBpm,
    this.rmssdMs,
    this.activity,
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      type: json['type'] as String? ?? 'UNKNOWN',
      level: json['level'] as String? ?? 'WATCH',
      detail: json['detail'] as String? ?? '',
      hrBpm: (json['hr_bpm'] as num?)?.toDouble(),
      rmssdMs: (json['rmssd_ms'] as num?)?.toDouble(),
      activity: json['activity'] as String?,
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'level': level,
      'detail': detail,
      'hr_bpm': hrBpm,
      'rmssd_ms': rmssdMs,
      'activity': activity,
      'is_read': isRead,
    };
  }

  /// Tạo AlertModel từ VitalsModel clinical_alerts
  factory AlertModel.fromClinicalAlert(
    Map<String, dynamic> clinicalAlert, {
    required DateTime timestamp,
    double? hrBpm,
    double? rmssdMs,
    String? activity,
  }) {
    return AlertModel(
      id: '${timestamp.millisecondsSinceEpoch}_${clinicalAlert['type']}',
      timestamp: timestamp,
      type: clinicalAlert['type'] as String? ?? 'UNKNOWN',
      level: clinicalAlert['level'] as String? ?? 'WATCH',
      detail: clinicalAlert['detail'] as String? ?? '',
      hrBpm: hrBpm,
      rmssdMs: rmssdMs,
      activity: activity,
    );
  }

  bool get isCritical => level.toUpperCase() == 'CRITICAL';
  bool get isAlert => level.toUpperCase() == 'ALERT';
  bool get isWatch => level.toUpperCase() == 'WATCH';

  int get severityLevel {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return 4;
      case 'ALERT':
        return 3;
      case 'WATCH':
        return 2;
      default:
        return 1;
    }
  }

  AlertModel copyWith({
    String? id,
    DateTime? timestamp,
    String? type,
    String? level,
    String? detail,
    double? hrBpm,
    double? rmssdMs,
    String? activity,
    bool? isRead,
  }) {
    return AlertModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      level: level ?? this.level,
      detail: detail ?? this.detail,
      hrBpm: hrBpm ?? this.hrBpm,
      rmssdMs: rmssdMs ?? this.rmssdMs,
      activity: activity ?? this.activity,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Thời gian tương đối (vd: "5 phút trước")
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}
