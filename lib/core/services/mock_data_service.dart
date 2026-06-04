import 'dart:async';
import 'dart:math';

/// Service tạo dữ liệu giả cho demo/test
/// Mô phỏng Jetson Nano gửi vitals mỗi 3 giây (thay vì 30s để demo nhanh)
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final _random = Random();
  Timer? _vitalsTimer;
  Timer? _alertTimer;

  final _vitalsController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get vitalsStream => _vitalsController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Trạng thái nội bộ mô phỏng
  double _baseHr = 72.0;
  String _currentActivity = 'rest';
  String _currentEmotion = 'calm';
  int _tickCount = 0;

  /// Bắt đầu stream dữ liệu mock
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Gửi vitals mỗi 3 giây
    _vitalsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _tickCount++;
      _generateVitals();
    });

    // Gửi alert ngẫu nhiên mỗi 30-60 giây
    _scheduleNextAlert();
  }

  /// Dừng stream
  void stop() {
    _isRunning = false;
    _vitalsTimer?.cancel();
    _alertTimer?.cancel();
  }

  /// Tạo vitals giả thực tế
  void _generateVitals() {
    // Thay đổi hoạt động mỗi 10 ticks (~30 giây)
    if (_tickCount % 10 == 0) {
      _currentActivity = _randomActivity();
    }

    // Thay đổi cảm xúc mỗi 20 ticks (~60 giây)
    if (_tickCount % 20 == 0) {
      _currentEmotion = _randomEmotion();
    }

    // HR thay đổi theo hoạt động
    switch (_currentActivity) {
      case 'rest':
        _baseHr = 65 + _random.nextDouble() * 10; // 65-75
        break;
      case 'slow_walk':
        _baseHr = 75 + _random.nextDouble() * 15; // 75-90
        break;
      case 'walk':
        _baseHr = 85 + _random.nextDouble() * 20; // 85-105
        break;
      case 'active':
        _baseHr = 95 + _random.nextDouble() * 25; // 95-120
        break;
    }

    // Thêm nhiễu nhỏ
    final hr = _baseHr + (_random.nextDouble() - 0.5) * 4;
    final rmssd = _currentActivity == 'rest'
        ? 25 + _random.nextDouble() * 20 // 25-45 khi nghỉ
        : 15 + _random.nextDouble() * 15; // 15-30 khi vận động
    final stressLabel = _currentEmotion == 'stressed' ? 'stress' : 'non_stress';
    final stressConfidence = 0.70 + _random.nextDouble() * 0.25;
    final lfHf = stressLabel == 'stress'
        ? 2.5 + _random.nextDouble() * 2 // Cao khi stress
        : 0.8 + _random.nextDouble() * 1.2; // Bình thường

    // Xác định alert level
    String alertLevel = 'SAFE';
    if (hr > 110) alertLevel = 'WATCH';
    if (hr > 120) alertLevel = 'ALERT';
    if (hr > 140 || hr < 45) alertLevel = 'CRITICAL';

    final vitals = {
      'timestamp': DateTime.now().toIso8601String(),
      'hr_bpm': double.parse(hr.toStringAsFixed(1)),
      'rr_ms': double.parse((60000 / hr).toStringAsFixed(1)),
      'rmssd_ms': double.parse(rmssd.toStringAsFixed(1)),
      'sdnn_ms': double.parse((rmssd * 1.3).toStringAsFixed(1)),
      'lf_hf_ratio': double.parse(lfHf.toStringAsFixed(2)),
      'rmssd_normal': rmssd > 20 ? 'normal' : 'low',
      'beat_type': 'N',
      'beat_confidence': 0.95 + _random.nextDouble() * 0.05,
      'activity': _currentActivity,
      'activity_confidence': 0.85 + _random.nextDouble() * 0.15,
      'stress': {
        'label': stressLabel,
        'confidence': stressConfidence,
        'probabilities': {
          'non_stress':
              stressLabel == 'stress' ? 1 - stressConfidence : stressConfidence,
          'stress':
              stressLabel == 'stress' ? stressConfidence : 1 - stressConfidence,
        },
      },
      'emotion': _currentEmotion,
      'emotion_confidence': stressConfidence,
      'anomaly_score': 0.0,
      'anomaly': {
        'label': 'normal',
        'value': 0,
        'anomaly_windows': 0,
        'total_windows': 6,
        'model_source': 'mock_global_legacy',
      },
      'alert_level': alertLevel,
      'clinical_alerts': alertLevel != 'SAFE' ? ['HR_ABNORMAL'] : [],
      'latency_ms': 50 + _random.nextInt(100),
    };

    _vitalsController.add(vitals);
  }

  void _scheduleNextAlert() {
    final delaySeconds = 30 + _random.nextInt(30);
    _alertTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isRunning) return;
      _generateAlert();
      _scheduleNextAlert();
    });
  }

  void _generateAlert() {
    final types = [
      'TACHYCARDIA',
      'BRADYCARDIA',
      'VERY_LOW_HRV',
      'IRREGULAR_RHYTHM',
      'FALL_DETECTED',
    ];
    final levels = ['WATCH', 'ALERT', 'CRITICAL'];
    final type = types[_random.nextInt(types.length)];
    final level = type == 'FALL_DETECTED'
        ? 'CRITICAL'
        : levels[_random.nextInt(levels.length)];

    final alert = {
      'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'level': level,
      'hr_bpm': 60 + _random.nextInt(80).toDouble(),
      'rmssd_ms': 10 + _random.nextDouble() * 30,
      'activity': _currentActivity,
      'message': _alertMessage(type),
    };

    _alertController.add(alert);
  }

  String _alertMessage(String type) {
    switch (type) {
      case 'TACHYCARDIA':
        return 'Nhịp tim tăng cao bất thường';
      case 'BRADYCARDIA':
        return 'Nhịp tim giảm thấp bất thường';
      case 'VERY_LOW_HRV':
        return 'Biến thiên nhịp tim rất thấp';
      case 'IRREGULAR_RHYTHM':
        return 'Phát hiện nhịp tim không đều';
      case 'FALL_DETECTED':
        return '⚠️ Phát hiện ngã! Kiểm tra ngay!';
      default:
        return 'Cảnh báo sức khỏe';
    }
  }

  String _randomActivity() {
    const activities = ['rest', 'rest', 'rest', 'slow_walk', 'walk', 'active'];
    return activities[_random.nextInt(activities.length)];
  }

  String _randomEmotion() {
    const emotions = ['calm', 'calm', 'calm', 'positive', 'stressed'];
    return emotions[_random.nextInt(emotions.length)];
  }

  /// Tạo dữ liệu lịch sử cho N giờ trước
  List<Map<String, dynamic>> generateHistory({int hours = 24}) {
    final points = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final intervalMinutes = 2; // Mỗi 2 phút 1 điểm
    final totalPoints = (hours * 60) ~/ intervalMinutes;

    for (int i = totalPoints; i >= 0; i--) {
      final timestamp = now.subtract(Duration(minutes: i * intervalMinutes));
      final hourOfDay = timestamp.hour;

      // HR thay đổi theo giờ trong ngày
      double baseHr;
      if (hourOfDay >= 0 && hourOfDay < 6) {
        baseHr = 58 + _random.nextDouble() * 8; // Ban đêm: thấp
      } else if (hourOfDay >= 6 && hourOfDay < 9) {
        baseHr = 68 + _random.nextDouble() * 12; // Sáng sớm
      } else if (hourOfDay >= 9 && hourOfDay < 12) {
        baseHr = 72 + _random.nextDouble() * 15; // Buổi sáng
      } else if (hourOfDay >= 12 && hourOfDay < 14) {
        baseHr = 70 + _random.nextDouble() * 10; // Sau ăn trưa
      } else if (hourOfDay >= 14 && hourOfDay < 18) {
        baseHr = 68 + _random.nextDouble() * 18; // Chiều
      } else {
        baseHr = 65 + _random.nextDouble() * 12; // Tối
      }

      // Thỉnh thoảng có spike
      if (_random.nextDouble() < 0.05) {
        baseHr += 20 + _random.nextDouble() * 15;
      }

      final rmssd = 20 + _random.nextDouble() * 25;
      final activities = ['rest', 'slow_walk', 'walk', 'active'];
      final stresses = ['non_stress', 'non_stress', 'stress'];
      final stress = stresses[_random.nextInt(stresses.length)];

      points.add({
        'timestamp': timestamp.toIso8601String(),
        'hr_bpm': double.parse(baseHr.toStringAsFixed(1)),
        'rmssd_ms': double.parse(rmssd.toStringAsFixed(1)),
        'sdnn_ms': double.parse((rmssd * 1.3).toStringAsFixed(1)),
        'lf_hf_ratio': 0.5 + _random.nextDouble() * 2.5,
        'activity': activities[_random.nextInt(activities.length)],
        'stress': {
          'label': stress,
          'confidence': 0.70 + _random.nextDouble() * 0.25,
        },
        'emotion': stress == 'stress' ? 'stressed' : 'calm',
        'alert_level': baseHr > 100 ? 'WATCH' : 'SAFE',
        'has_alert': baseHr > 110,
      });
    }

    return points;
  }

  /// Tạo alerts lịch sử
  List<Map<String, dynamic>> generateAlertHistory({int count = 15}) {
    final alerts = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final types = [
      'TACHYCARDIA',
      'BRADYCARDIA',
      'VERY_LOW_HRV',
      'IRREGULAR_RHYTHM',
      'FALL_DETECTED'
    ];
    final levels = ['WATCH', 'ALERT', 'CRITICAL'];

    for (int i = 0; i < count; i++) {
      final minutesAgo = _random.nextInt(7 * 24 * 60);
      final type = types[_random.nextInt(types.length)];

      alerts.add({
        'id': 'mock_hist_$i',
        'timestamp':
            now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
        'type': type,
        'level': type == 'FALL_DETECTED'
            ? 'CRITICAL'
            : levels[_random.nextInt(levels.length)],
        'hr_bpm': 60 + _random.nextInt(80).toDouble(),
        'rmssd_ms': 10 + _random.nextDouble() * 30,
        'activity': _randomActivity(),
        'message': _alertMessage(type),
      });
    }

    // Sort by time desc
    alerts.sort((a, b) => DateTime.parse(b['timestamp'])
        .compareTo(DateTime.parse(a['timestamp'])));
    return alerts;
  }

  /// Tạo user profile mẫu
  Map<String, dynamic> generateUserProfile() {
    return {
      'id': 'user_demo_001',
      'name': 'Nguyễn Văn An',
      'age': 72,
      'comorbidities': ['Tăng huyết áp', 'Tiểu đường type 2'],
      'medications': 'Amlodipine 5mg, Metformin 500mg',
      'calibration': {
        'is_calibrated': true,
        'calibrated_at':
            DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'needs_recalibration': false,
      },
      'emergency_contact': {
        'name': 'Nguyễn Thị Bình',
        'phone': '0901234567',
      },
    };
  }

  void dispose() {
    stop();
    _vitalsController.close();
    _alertController.close();
  }
}
