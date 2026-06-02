import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WifiNetwork {
  final String ssid;
  final int? signal;
  final String security;

  const WifiNetwork({
    required this.ssid,
    this.signal,
    this.security = '',
  });

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: (json['ssid'] ?? '').toString(),
      signal: json['signal'] is int
          ? json['signal'] as int
          : int.tryParse((json['signal'] ?? '').toString()),
      security: (json['security'] ?? '').toString(),
    );
  }
}

class WifiProvisioningStatus {
  final String mode;
  final String? connectedSsid;
  final bool internetReachable;
  final String? lastError;
  final String? setupSsid;
  final String? setupIp;
  final String? portalUrl;

  const WifiProvisioningStatus({
    required this.mode,
    this.connectedSsid,
    required this.internetReachable,
    this.lastError,
    this.setupSsid,
    this.setupIp,
    this.portalUrl,
  });

  factory WifiProvisioningStatus.fromJson(Map<String, dynamic> json) {
    return WifiProvisioningStatus(
      mode: (json['mode'] ?? 'unknown').toString(),
      connectedSsid: json['connected_ssid']?.toString(),
      internetReachable: json['internet_reachable'] == true,
      lastError: json['last_error']?.toString(),
      setupSsid: json['setup_ssid']?.toString(),
      setupIp: json['setup_ip']?.toString(),
      portalUrl: json['portal_url']?.toString(),
    );
  }
}

class WifiProvisioningService {
  WifiProvisioningService({String portalBaseUrl = defaultPortalBaseUrl})
      : _portalBaseUrl = portalBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  static const String defaultPortalBaseUrl = 'http://10.42.0.1';

  final Dio _dio;
  final String _portalBaseUrl;

  String get portalBaseUrl => _portalBaseUrl;

  Future<WifiProvisioningStatus> getStatus() async {
    try {
      final response = await _dio.get('$_portalBaseUrl/api/status');
      return WifiProvisioningStatus.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw WifiProvisioningException(
        'Khong ket noi duoc portal setup. Hay dam bao dien thoai dang noi Wi-Fi ElderlyCare-Setup. ${e.message}',
      );
    }
  }

  Future<List<WifiNetwork>> scanNetworks() async {
    try {
      final response = await _dio.get('$_portalBaseUrl/api/wifi/scan');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawNetworks = (data['networks'] as List<dynamic>?) ?? [];
      return rawNetworks
          .map((item) => WifiNetwork.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.ssid.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw WifiProvisioningException(
        'Khong quet duoc Wi-Fi tu Raspberry Pi. ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> connectWifi({
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty) {
      throw const WifiProvisioningException(
          'Vui long chon hoac nhap ten Wi-Fi.');
    }
    try {
      final response = await _dio.post(
        '$_portalBaseUrl/api/wifi/connect',
        data: {
          'ssid': ssid.trim(),
          'password': password,
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw WifiProvisioningException(
        'Khong gui duoc thong tin Wi-Fi sang Raspberry Pi. ${e.message}',
      );
    }
  }
}

class WifiProvisioningException implements Exception {
  final String message;
  const WifiProvisioningException(this.message);

  @override
  String toString() => message;
}

final wifiProvisioningServiceProvider =
    Provider<WifiProvisioningService>((ref) {
  return WifiProvisioningService();
});
