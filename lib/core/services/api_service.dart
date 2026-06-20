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
    String? apiKey,
    String? accessCode,
    String? deviceCode,
  }) {
    _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers.remove('X-API-Key');
    _dio.options.headers.remove('X-Access-Code');
    _dio.options.headers.remove('X-Device-Code');
    final effectiveKey = apiKey?.trim() ?? '';
    if (effectiveKey.isNotEmpty) {
      _dio.options.headers['X-API-Key'] = effectiveKey;
    }
  }

  /// GET /latest-result - latest model output.
  Future<Map<String, dynamic>> getLatestVitals() async {
    try {
      final response = await _dio.get('$_baseUrl/latest-result');
      final data = response.data as Map<String, dynamic>;
      return data;
    } on DioException catch (e) {
      throw ApiException('Cannot load latest vitals: ${e.message}');
    }
  }

  /// GET /health - backend, model, network provisioning, and Polar status.
  Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load backend health: ${e.message}');
    }
  }

  /// POST /polar/start - manually start Polar H10 collector when auto-start is unavailable.
  Future<Map<String, dynamic>> startPolarCollector({
    String? address,
    int chunkSeconds = 10,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/polar/start',
        data: {
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          'chunk_seconds': chunkSeconds,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot start Polar collector: ${e.message}');
    }
  }

  /// GET /history - stored prediction history.
  Future<Map<String, dynamic>> getHistory({
    int hours = 24,
    String? patientId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/history',
        queryParameters: {
          if (patientId != null && patientId.isNotEmpty)
            'patient_id': patientId,
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
  Future<List<dynamic>> getAlerts({
    int limit = 50,
    String? patientId,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/events',
        queryParameters: {
          if (patientId != null && patientId.isNotEmpty)
            'patient_id': patientId,
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

  /// GET /alerts/realtime - high/critical caregiver alerts with ack status.
  Future<List<dynamic>> getRealtimeAlerts({
    int limit = 50,
    String? patientId,
    bool includeAcknowledged = false,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/alerts/realtime',
        queryParameters: {
          if (patientId != null && patientId.isNotEmpty)
            'patient_id': patientId,
          'limit': limit,
          'include_acknowledged': includeAcknowledged,
        },
      );
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      return (response.data['alerts'] as List<dynamic>?) ?? [];
    } on DioException catch (e) {
      throw ApiException('Cannot load urgent alerts: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> acknowledgeAlert({
    required String eventId,
    required String caregiverId,
    String note = '',
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/alerts/$eventId/ack',
        data: {
          'caregiver_id': caregiverId,
          'note': note,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot acknowledge alert: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> resolveAlert({
    required String eventId,
    required String caregiverId,
    String resolution = 'checked_ok',
    String note = '',
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/alerts/$eventId/resolve',
        data: {
          'caregiver_id': caregiverId,
          'resolution': resolution,
          'note': note,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot resolve alert: ${e.message}');
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

  /// GET /daily-report - full per-calendar-day statistical report (MongoDB).
  /// [date] is YYYY-MM-DD.
  Future<Map<String, dynamic>> getDailyReport({
    required String date,
    String patientId = 'polar_h10',
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/daily-report',
        queryParameters: {
          'date': date,
          if (patientId.isNotEmpty) 'patient_id': patientId,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load daily report: ${e.message}');
    }
  }

  /// GET /period-report - weekly/monthly statistical report (MongoDB).
  /// [period] is 'week' or 'month'; [end] is an optional YYYY-MM-DD end date.
  Future<Map<String, dynamic>> getPeriodReport({
    String period = 'week',
    String patientId = 'polar_h10',
    String? end,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/period-report',
        queryParameters: {
          'period': period,
          if (patientId.isNotEmpty) 'patient_id': patientId,
          if (end != null && end.isNotEmpty) 'end': end,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Cannot load period report: ${e.message}');
    }
  }

  /// GET /daily-report/available-days - calendar days that have data.
  Future<List<dynamic>> getAvailableReportDays({
    String patientId = 'polar_h10',
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/daily-report/available-days',
        queryParameters: {if (patientId.isNotEmpty) 'patient_id': patientId},
      );
      final data = response.data;
      if (data is Map && data['days'] is List) {
        return data['days'] as List<dynamic>;
      }
      return [];
    } on DioException catch (e) {
      throw ApiException('Cannot load available report days: ${e.message}');
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
