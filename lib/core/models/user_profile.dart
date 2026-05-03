/// Model hồ sơ người dùng — từ GET /api/user/{id}
class UserProfile {
  final String id;
  final String name;
  final int age;
  final String? avatarUrl;
  final List<String> comorbidities;
  final String? medications;
  final PersonalThresholds thresholds;
  final CalibrationStatus calibration;
  final EmergencyContact? emergencyContact;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    this.avatarUrl,
    required this.comorbidities,
    this.medications,
    required this.thresholds,
    required this.calibration,
    this.emergencyContact,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      comorbidities: (json['comorbidities'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      medications: json['medications'] as String?,
      thresholds: json['thresholds'] != null
          ? PersonalThresholds.fromJson(
              json['thresholds'] as Map<String, dynamic>)
          : const PersonalThresholds(),
      calibration: json['calibration'] != null
          ? CalibrationStatus.fromJson(
              json['calibration'] as Map<String, dynamic>)
          : const CalibrationStatus(),
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(
              json['emergency_contact'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'avatar_url': avatarUrl,
      'comorbidities': comorbidities,
      'medications': medications,
      'thresholds': thresholds.toJson(),
      'calibration': calibration.toJson(),
      'emergency_contact': emergencyContact?.toJson(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    String? avatarUrl,
    List<String>? comorbidities,
    String? medications,
    PersonalThresholds? thresholds,
    CalibrationStatus? calibration,
    EmergencyContact? emergencyContact,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      comorbidities: comorbidities ?? this.comorbidities,
      medications: medications ?? this.medications,
      thresholds: thresholds ?? this.thresholds,
      calibration: calibration ?? this.calibration,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  /// Default profile for first-time users
  factory UserProfile.empty() {
    return const UserProfile(
      id: 'default',
      name: '',
      age: 65,
      comorbidities: [],
      thresholds: PersonalThresholds(),
      calibration: CalibrationStatus(),
    );
  }
}

/// Ngưỡng cá nhân hóa
class PersonalThresholds {
  final double hrLow;
  final double hrHigh;
  final double rmssdMin;
  final bool autoAdjust;

  const PersonalThresholds({
    this.hrLow = 50.0,
    this.hrHigh = 100.0,
    this.rmssdMin = 15.0,
    this.autoAdjust = true,
  });

  factory PersonalThresholds.fromJson(Map<String, dynamic> json) {
    return PersonalThresholds(
      hrLow: (json['hr_low'] as num?)?.toDouble() ?? 50.0,
      hrHigh: (json['hr_high'] as num?)?.toDouble() ?? 100.0,
      rmssdMin: (json['rmssd_min'] as num?)?.toDouble() ?? 15.0,
      autoAdjust: json['auto_adjust'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hr_low': hrLow,
      'hr_high': hrHigh,
      'rmssd_min': rmssdMin,
      'auto_adjust': autoAdjust,
    };
  }
}

/// Trạng thái calibration
class CalibrationStatus {
  final bool isCalibrated;
  final DateTime? calibratedAt;
  final bool needsRecalibration;

  const CalibrationStatus({
    this.isCalibrated = false,
    this.calibratedAt,
    this.needsRecalibration = false,
  });

  factory CalibrationStatus.fromJson(Map<String, dynamic> json) {
    return CalibrationStatus(
      isCalibrated: json['is_calibrated'] as bool? ?? false,
      calibratedAt: json['calibrated_at'] != null
          ? DateTime.parse(json['calibrated_at'] as String)
          : null,
      needsRecalibration: json['needs_recalibration'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_calibrated': isCalibrated,
      'calibrated_at': calibratedAt?.toIso8601String(),
      'needs_recalibration': needsRecalibration,
    };
  }

  /// Cần calibrate lại nếu > 7 ngày
  bool get isExpired {
    if (!isCalibrated || calibratedAt == null) return false;
    return DateTime.now().difference(calibratedAt!).inDays > 7;
  }
}

/// Liên hệ khẩn cấp
class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({
    required this.name,
    required this.phone,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}
