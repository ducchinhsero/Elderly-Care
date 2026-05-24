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
  final Map<String, dynamic> metadata;
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
    this.metadata = const {},
    this.isRead = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final eventType = json['event_type'] as String?;
    final severity = json['severity'] as String?;
    return AlertModel(
      id: json['id'] as String? ??
          json['event_id'] as String? ??
          '${json['timestamp']}_${eventType ?? json['type'] ?? 'alert'}',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      type: json['type'] as String? ?? eventType ?? 'UNKNOWN',
      level: _mapAlertLevel(json['level'] as String? ?? severity ?? 'WATCH'),
      detail: json['detail'] as String? ??
          json['message'] as String? ??
          json['label'] as String? ??
          '',
      hrBpm: (json['heart_rate_bpm'] as num?)?.toDouble() ??
          (json['hr_bpm'] as num?)?.toDouble(),
      rmssdMs: (json['rmssd_ms'] as num?)?.toDouble(),
      activity:
          json['activity_state'] as String? ?? json['activity'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
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
      'metadata': metadata,
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
      metadata: clinicalAlert,
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

  String get userTitle {
    final key = type.toLowerCase();
    if (key.contains('fall')) return 'Nghi ngo te nga';
    if (key.contains('afib') || key.contains('rhythm')) {
      return 'Bat thuong nhip tim';
    }
    if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
      return 'Hoat dong PVC/PAC';
    }
    if (key.contains('tachy')) return 'Nhip tim nhanh';
    if (key.contains('brady')) return 'Nhip tim cham';
    if (key.contains('poor_signal') || key.contains('signal')) {
      return 'Tin hieu do kem';
    }
    return 'Canh bao suc khoe';
  }

  String get userDetail {
    if (detail.isNotEmpty) return detail;
    final key = type.toLowerCase();
    if (key.contains('fall')) {
      return 'He thong phat hien mau van dong co the la te nga.';
    }
    if (key.contains('afib') || key.contains('rhythm')) {
      return 'Nhip tim co mau bat thuong can theo doi them.';
    }
    if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
      return 'Co dau hieu PVC/PAC hoac nhip den som trong cua so do.';
    }
    if (key.contains('tachy')) return 'Nhip tim cao hon nguong theo boi canh.';
    if (key.contains('brady')) return 'Nhip tim thap hon nguong theo boi canh.';
    if (key.contains('poor_signal') || key.contains('signal')) {
      return 'Chat luong tin hieu ECG co the lam giam do tin cay.';
    }
    return 'Can xem lai su kien va tiep tuc theo doi.';
  }

  String get actionText {
    final key = type.toLowerCase();
    if (isCritical || key.contains('fall')) {
      return 'Kiem tra nguoi dung ngay.';
    }
    if (isAlert) {
      return 'Ghi nhan trieu chung va trao doi voi nhan vien y te neu tinh trang lap lai.';
    }
    if (isWatch) {
      return 'Theo doi them va kiem tra lai neu co trieu chung.';
    }
    return 'Luu lai de theo doi xu huong.';
  }

  String get severityGroup {
    if (isCritical) return 'Can ho tro ngay';
    if (isAlert) return 'Nen trao doi y te';
    if (isWatch) return 'Can theo doi';
    return 'Thong tin';
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
    Map<String, dynamic>? metadata,
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
      metadata: metadata ?? this.metadata,
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

String _mapAlertLevel(String value) {
  switch (value.toLowerCase()) {
    case 'critical':
      return 'CRITICAL';
    case 'high':
    case 'alert':
      return 'ALERT';
    case 'medium':
    case 'watch':
    case 'unknown':
      return 'WATCH';
    case 'low':
    case 'normal':
    case 'safe':
    default:
      return 'SAFE';
  }
}
