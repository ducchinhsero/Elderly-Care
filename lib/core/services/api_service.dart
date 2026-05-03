import 'package:dio/dio.dart';

/// Service gọi FastAPI backend qua HTTP
class ApiService {
  late final Dio _dio;
  String _baseUrl = 'http://192.168.1.100:8000';

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Interceptor cho logging (debug)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  /// Cấu hình base URL
  void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  /// GET /api/health — vitals mới nhất
  Future<Map<String, dynamic>> getLatestVitals() async {
    try {
      final response = await _dio.get('$_baseUrl/api/health');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Không thể lấy dữ liệu vitals: ${e.message}');
    }
  }

  /// GET /api/history?hours=N — lịch sử
  Future<List<dynamic>> getHistory({int hours = 24}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/history',
        queryParameters: {'hours': hours},
      );
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      return (response.data['data'] as List<dynamic>?) ?? [];
    } on DioException catch (e) {
      throw ApiException('Không thể lấy lịch sử: ${e.message}');
    }
  }

  /// GET /api/alerts?limit=N — danh sách alerts gần nhất
  Future<List<dynamic>> getAlerts({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/alerts',
        queryParameters: {'limit': limit},
      );
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      return (response.data['alerts'] as List<dynamic>?) ?? [];
    } on DioException catch (e) {
      throw ApiException('Không thể lấy cảnh báo: ${e.message}');
    }
  }

  /// GET /api/user/{id} — thông tin người dùng
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('$_baseUrl/api/user/$userId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Không thể lấy thông tin người dùng: ${e.message}');
    }
  }

  /// POST /api/calibrate — trigger calibration 30 phút
  Future<Map<String, dynamic>> startCalibration() async {
    try {
      final response = await _dio.post('$_baseUrl/api/calibrate');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException('Không thể bắt đầu calibration: ${e.message}');
    }
  }

  /// Health check — kiểm tra backend có sống không
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Custom exception cho API errors
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
