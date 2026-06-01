import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanDevice {
  final String host;
  final String baseUrl;
  final Map<String, dynamic> health;

  const LanDevice({
    required this.host,
    required this.baseUrl,
    required this.health,
  });

  String get label {
    final status = health['status']?.toString();
    final network = health['network_setup'];
    if (network is Map && network['mode'] != null) {
      return '$host - ${network['mode']}';
    }
    return status == null ? host : '$host - $status';
  }
}

typedef LanHealthChecker = Future<LanDevice?> Function(String host);

class LanSetupService {
  LanSetupService({
    Dio? dio,
    LanHealthChecker? healthChecker,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            ),
        _healthChecker = healthChecker;

  final Dio _dio;
  final LanHealthChecker? _healthChecker;

  static String normalizeGatewayHost(String input) {
    var value = input.trim();
    value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    value = value.split('/').first;
    value = value.split('?').first;
    value = value.split('#').first;
    if (value.contains('@')) {
      value = value.split('@').last;
    }
    final hostPort = RegExp(r'^([^:]+):\d+$').firstMatch(value);
    if (hostPort != null) {
      value = hostPort.group(1) ?? value;
    }
    return value.trim();
  }

  static String baseUrlForHost(String host) {
    final normalized = normalizeGatewayHost(host);
    if (normalized.isEmpty) {
      throw const LanSetupException(
          'Vui lòng nhập IP hoặc hostname Raspberry.');
    }
    return 'http://$normalized:8000';
  }

  static bool isPrivateIpv4(String address) {
    final parts = _ipv4Parts(address);
    if (parts == null) return false;
    final a = parts[0];
    final b = parts[1];
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  static Set<String> candidateHostsForAddress(String address) {
    final parts = _ipv4Parts(address);
    if (parts == null || !isPrivateIpv4(address)) return {};

    final hosts = <String>{};
    for (final third in [parts[2] - 1, parts[2], parts[2] + 1]) {
      if (third < 0 || third > 255) continue;
      for (var last = 1; last <= 254; last += 1) {
        if (third == parts[2] && last == parts[3]) continue;
        hosts.add('${parts[0]}.${parts[1]}.$third.$last');
      }
    }
    return hosts;
  }

  Future<LanDevice> checkHealth(
    String host, {
    String? apiKey,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final normalized = normalizeGatewayHost(host);
    final baseUrl = baseUrlForHost(normalized);
    try {
      final response = await _dio.get(
        '$baseUrl/health',
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {
            if ((apiKey ?? '').trim().isNotEmpty) 'X-API-Key': apiKey!.trim(),
          },
        ),
      );
      if (response.data is! Map) {
        throw const LanSetupException(
            'Backend trả dữ liệu /health không hợp lệ.');
      }
      final health = Map<String, dynamic>.from(response.data as Map);
      return LanDevice(host: normalized, baseUrl: baseUrl, health: health);
    } on LanSetupException {
      rethrow;
    } on DioException catch (e) {
      throw LanSetupException(
        'Không kết nối được Raspberry tại $baseUrl. Kiểm tra dây LAN, IP và backend port 8000. ${e.message ?? ''}',
      );
    } catch (e) {
      throw LanSetupException('Không kiểm tra được Raspberry tại $baseUrl: $e');
    }
  }

  Future<List<LanDevice>> scanLan({
    String? apiKey,
    int concurrency = 64,
    int maxResults = 12,
    Duration timeout = const Duration(milliseconds: 700),
    Iterable<String>? candidateHosts,
  }) async {
    final candidates = <String>{};
    if (candidateHosts != null) {
      candidates.addAll(candidateHosts.map(normalizeGatewayHost));
    } else {
      final localHosts = await _localPrivateIpv4Addresses();
      for (final host in localHosts) {
        candidates.addAll(candidateHostsForAddress(host));
      }
    }
    if (candidates.isEmpty) {
      throw const LanSetupException(
        'Không tìm thấy mạng LAN private trên thiết bị này. Hãy nhập IP Raspberry thủ công.',
      );
    }

    final queue = Queue<String>.from(candidates);
    final results = <LanDevice>[];
    final workerCount = concurrency.clamp(1, 128).toInt();

    Future<void> worker() async {
      while (queue.isNotEmpty && results.length < maxResults) {
        final host = queue.removeFirst();
        try {
          final future = _healthChecker == null
              ? checkHealth(host, apiKey: apiKey, timeout: timeout)
              : _healthChecker(host);
          final device = await future.timeout(timeout);
          if (device != null) {
            results.add(device);
          }
        } catch (_) {
          // Scanning intentionally ignores unreachable LAN hosts.
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    results.sort((a, b) => a.host.compareTo(b.host));
    return results;
  }

  Future<List<String>> _localPrivateIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>[];
    for (final iface in interfaces) {
      for (final address in iface.addresses) {
        if (isPrivateIpv4(address.address)) {
          addresses.add(address.address);
        }
      }
    }
    return addresses;
  }

  static List<int>? _ipv4Parts(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return null;
    final parsed = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
      parsed.add(value);
    }
    return parsed;
  }
}

class LanSetupException implements Exception {
  final String message;
  const LanSetupException(this.message);

  @override
  String toString() => message;
}

final lanSetupServiceProvider = Provider<LanSetupService>((ref) {
  return LanSetupService();
});
