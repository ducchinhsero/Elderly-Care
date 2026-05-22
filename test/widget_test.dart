// Smoke / unit tests cho elder_health_monitor.
//
// Tránh phụ thuộc vào google_fonts (cần truy cập mạng) bằng cách kiểm tra
// các logic độc lập không liên quan đến UI thực tế.

// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:elder_health_monitor/core/services/storage_service.dart';
import 'package:elder_health_monitor/core/services/mqtt_service.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tmp);
  final String tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;

  @override
  Future<String?> getApplicationSupportPath() async => tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService storage;
    late Directory tmp;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('eh_test_');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      Hive.init(tmp.path);
      storage = StorageService();
      await storage.init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('giá trị mặc định hợp lý', () {
      expect(storage.gatewayIp, '127.0.0.1');
      expect(storage.isDemoMode, isFalse);
      expect(storage.mqttPort, 1883);
      expect(storage.autoReconnect, isTrue);
      expect(storage.isDarkMode, isFalse);
      expect(storage.notifCritical, isTrue);
      expect(storage.userRole, '');
      expect(storage.hasSelectedRole, isFalse);
      expect(storage.onboardingCompleted, isFalse);
    });

    test('lưu và đọc được vai trò người dùng', () async {
      await storage.setUserRole('caregiver');
      expect(storage.userRole, 'caregiver');
      expect(storage.isCaregiver, isTrue);
      expect(storage.isWearer, isFalse);
      expect(storage.hasSelectedRole, isTrue);
    });

    test('apiBaseUrl thay đổi theo role và cloudUrl', () async {
      // Mặc định: wearer → dùng gateway IP
      await storage.setGatewayIp('10.0.0.5');
      expect(storage.apiBaseUrl, 'http://10.0.0.5:8000');

      // Caregiver có cloudUrl → dùng cloudUrl
      await storage.setUserRole('caregiver');
      await storage.setCloudUrl('https://api.example.com');
      expect(storage.apiBaseUrl, 'https://api.example.com');

      // Caregiver nhưng cloudUrl rỗng → fallback gateway IP
      await storage.setCloudUrl('');
      expect(storage.apiBaseUrl, 'http://10.0.0.5:8000');
    });
  });

  group('MqttConnectionState enum', () {
    test('có đủ 4 trạng thái', () {
      expect(MqttConnectionState.values, hasLength(4));
      expect(MqttConnectionState.values, contains(MqttConnectionState.connected));
      expect(MqttConnectionState.values, contains(MqttConnectionState.connecting));
      expect(MqttConnectionState.values, contains(MqttConnectionState.disconnected));
      expect(MqttConnectionState.values, contains(MqttConnectionState.reconnecting));
    });
  });
}
