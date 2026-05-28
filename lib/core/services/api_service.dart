import 'package:dio/dio.dart';

/// HTTP client for the ECG pipeline FastAPI backend.
class ApiService {
  static const bool _enableApiLogs = bool.fromEnvironment('ENABLE_API_LOGS');

  late final Dio _dio;
  String _baseUrl = 'http://127.0.0.1:8000';

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (_enableApiLogs) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
      ));
    }
  }

  String get baseUrl => _baseUrl;

  void configure({
    required String baseUrl,
    String? accessCode,
    String? deviceCode,
  }) {
    _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers.remove('X-Access-Code');
    _dio.options.headers.remove('X-Device-Code');
    if (accessCode != null && accessCode.trim().isNotEmpty) {
      _dio.options.headers['X-Access-Code'] = accessCode.trim();
    }
    if (deviceCode != null && deviceCode.trim().isNotEmpty) {
      _dio.options.headers['X-Device-Code'] = deviceCode.trim();
    }
  }

  /// GET /latest-result - latest model output.
  Future<Map<String, dynamic>> getLatestVitals() async {
    try {
      final response = await _dio.get('$_baseUrl/latest-result');
      final data = response.data as Map<String, dynamic>;
      return (data['latest_result'] as Map<String, dynamic>?) ?? data;
    } on DioException catch (e) {
      throw ApiException('Cannot load latest vitals: ${e.message}');
    }
  }

  /// GET /history - stored prediction history.
  Future<Map<String, dynamic>> getHistory({int hours = 24}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/history',
        queryParameters: {
          'days': hours / 24.0,
          'limit': 5000,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load history: ${e.message}');
    }
  }

  /// GET /events - event timeline used as app alerts.
  Future<List<dynamic>> getAlerts({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/events',
        queryParameters: {
          'days': 7,
          'limit': limit,
        },
      );
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      return (response.data['events'] as List<dynamic>?) ?? [];
    } on DioException catch (e) {
      throw ApiException('Cannot load alerts: ${e.message}');
    }
  }

  /// GET /health-report - realtime, 24h, and long-term assessment.
  Future<Map<String, dynamic>> getHealthReport({
    String? patientId,
    double dailyHours = 24,
    double longTermDays = 7,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/health-report',
        queryParameters: {
          if (patientId != null && patientId.isNotEmpty)
            'patient_id': patientId,
          'daily_hours': dailyHours,
          'long_term_days': longTermDays,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load health report: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/api/user/$userId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load user profile: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> startCalibration() async {
    try {
      final response =
          await _dio.post('$_baseUrl/personal-baseline/update-progressive');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot start calibration: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getGuidedBaselineStatus({
    String patientId = 'polar_h10',
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/guided-baseline/status',
        queryParameters: {'patient_id': patientId},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load guided baseline status: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> startGuidedBaseline({
    String patientId = 'polar_h10',
    int targetDays = 7,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/guided-baseline/start',
        data: {
          'patient_id': patientId,
          'target_days': targetDays,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot start guided baseline: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> completeGuidedBaselineSegment({
    required String patientId,
    required String sessionId,
    required String segmentType,
    DateTime? startedAt,
    DateTime? endedAt,
    bool allowSkip = false,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/guided-baseline/segment/complete',
        data: {
          'patient_id': patientId,
          'session_id': sessionId,
          'segment_type': segmentType,
          if (startedAt != null) 'started_at': startedAt.toIso8601String(),
          if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
          'allow_skip': allowSkip,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot complete guided segment: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> completeGuidedBaselineDay({
    required String patientId,
    required String sessionId,
    int targetDays = 7,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/guided-baseline/complete-day',
        data: {
          'patient_id': patientId,
          'session_id': sessionId,
          'target_days': targetDays,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot complete guided baseline day: ${e.message}');
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
