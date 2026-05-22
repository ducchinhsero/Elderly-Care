class UserProfile {
  int isarId;

  String uid;

  String fullName;
  DateTime dateOfBirth;

  int get age {
    final now = DateTime.now();
    int a = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      a--;
    }
    return a;
  }

  String gender; // "male" | "female"
  double? weightKg;
  double? heightCm;
  String? avatarPath;
  String? emergencyContactName;
  String? emergencyContactPhone;

  List<String> comorbidities;
  List<String> medications;

  int? restingHrBaseline;
  double? rmssdBaseline;
  String? primaryPhysician;
  String? physicianPhone;
  String? medicalNotes;

  DateTime? lastCalibratedAt;
  bool isCalibrated;

  PersonalizedThresholds? thresholds;

  UserProfile({
    this.isarId = 0,
    required this.uid,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    this.weightKg,
    this.heightCm,
    this.avatarPath,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.comorbidities = const [],
    this.medications = const [],
    this.restingHrBaseline,
    this.rmssdBaseline,
    this.primaryPhysician,
    this.physicianPhone,
    this.medicalNotes,
    this.lastCalibratedAt,
    this.isCalibrated = false,
    this.thresholds,
  });

  bool get needsRecalibration =>
      lastCalibratedAt == null ||
      DateTime.now().difference(lastCalibratedAt!).inDays > 7;

  Map<String, dynamic> get effectiveThresholds {
    double hrLow = thresholds?.hrLow ?? 50.0;
    double hrHigh = thresholds?.hrHigh ?? 100.0;
    double hrCritical = thresholds?.hrCritical ?? 130.0;
    double rmssdMin = thresholds?.rmssdMin ?? 18.0;
    double rrCvMax = thresholds?.rrCvMax ?? 0.15;
    bool warnIrregular = true;

    // Adjust based on medications
    if (medications.contains('beta_blocker')) {
      hrLow = 45.0; 
    }
    if (medications.contains('pacemaker')) {
      warnIrregular = false; 
    }

    // Adjust based on comorbidities
    if (comorbidities.contains('af_known')) {
      warnIrregular = false;
      hrHigh = 130.0; 
      hrCritical = 150.0;
    }
    if (comorbidities.contains('diabetes_t2') || comorbidities.contains('diabetes_t1')) {
      rmssdMin = 13.0;
    }

    return {
      'hr_low': hrLow,
      'hr_high': hrHigh,
      'hr_critical': hrCritical,
      'rmssd_min': rmssdMin,
      'rr_cv_max': rrCvMax,
      'warn_irregular': warnIrregular,
    };
  }

  factory UserProfile.empty() {
    return UserProfile(
      uid: 'default',
      fullName: 'Người Dùng',
      dateOfBirth: DateTime.now().subtract(const Duration(days: 65 * 365)),
      gender: 'male',
      comorbidities: [],
      medications: [],
      isCalibrated: false,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['id'] as String? ?? 'default',
      fullName: json['name'] as String? ?? 'Người Dùng',
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth']) 
          : DateTime.now().subtract(Duration(days: (json['age'] ?? 65) * 365)),
      gender: json['gender'] as String? ?? 'male',
      comorbidities: (json['comorbidities'] as List<dynamic>?)?.cast<String>() ?? [],
      medications: json['medications'] is String 
          ? [json['medications'] as String] 
          : (json['medications'] as List<dynamic>?)?.cast<String>() ?? [],
      isCalibrated: json['calibration']?['is_calibrated'] as bool? ?? false,
      lastCalibratedAt: json['calibration']?['calibrated_at'] != null
          ? DateTime.parse(json['calibration']['calibrated_at'])
          : null,
      emergencyContactName: json['emergency_contact']?['name'] as String?,
      emergencyContactPhone: json['emergency_contact']?['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'name': fullName,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'age': age,
      'gender': gender,
      'comorbidities': comorbidities,
      'medications': medications,
      'calibration': {
        'is_calibrated': isCalibrated,
        'calibrated_at': lastCalibratedAt?.toIso8601String(),
        'needs_recalibration': needsRecalibration,
      },
      'emergency_contact': {
        'name': emergencyContactName ?? '',
        'phone': emergencyContactPhone ?? '',
      }
    };
  }

  UserProfile copyWith({
    String? uid,
    String? fullName,
    DateTime? dateOfBirth,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? avatarPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    List<String>? comorbidities,
    List<String>? medications,
    int? restingHrBaseline,
    double? rmssdBaseline,
    String? primaryPhysician,
    String? physicianPhone,
    String? medicalNotes,
    DateTime? lastCalibratedAt,
    bool? isCalibrated,
    PersonalizedThresholds? thresholds,
  }) {
    return UserProfile(
      isarId: isarId, 
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      avatarPath: avatarPath ?? this.avatarPath,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      comorbidities: comorbidities ?? this.comorbidities,
      medications: medications ?? this.medications,
      restingHrBaseline: restingHrBaseline ?? this.restingHrBaseline,
      rmssdBaseline: rmssdBaseline ?? this.rmssdBaseline,
      primaryPhysician: primaryPhysician ?? this.primaryPhysician,
      physicianPhone: physicianPhone ?? this.physicianPhone,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      lastCalibratedAt: lastCalibratedAt ?? this.lastCalibratedAt,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      thresholds: thresholds ?? this.thresholds,
    );
  }
}

class PersonalizedThresholds {
  double hrLow;
  double hrHigh;
  double hrCritical;
  double rmssdMin;
  double rrCvMax;

  PersonalizedThresholds({
    this.hrLow = 50.0,
    this.hrHigh = 100.0,
    this.hrCritical = 130.0,
    this.rmssdMin = 18.0,
    this.rrCvMax = 0.15,
  });
}
