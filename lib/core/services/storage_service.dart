import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service quản lý local storage với Hive
class StorageService {
  static const String _settingsBox = 'settings';
  static const String _alertsBox = 'alerts';
  static const String _cacheBox = 'cache';

  late Box _settingsBoxInstance;
  late Box _alertsBoxInstance;
  late Box _cacheBoxInstance;

  /// Khởi tạo Hive — mở các boxes (Hive.initFlutter đã gọi trong main)
  Future<void> init() async {
    _settingsBoxInstance = await Hive.openBox(_settingsBox);
    _alertsBoxInstance = await Hive.openBox(_alertsBox);
    _cacheBoxInstance = await Hive.openBox(_cacheBox);
  }

  // ─── Settings ───

  /// Lưu setting
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBoxInstance.put(key, value);
  }

  /// Đọc setting
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBoxInstance.get(key, defaultValue: defaultValue) as T?;
  }

  /// Gateway IP
  String get gatewayIp =>
      getSetting<String>('gateway_ip', defaultValue: '192.168.1.100')!;
  Future<void> setGatewayIp(String ip) => saveSetting('gateway_ip', ip);

  /// MQTT Port
  int get mqttPort =>
      getSetting<int>('mqtt_port', defaultValue: 1883)!;
  Future<void> setMqttPort(int port) => saveSetting('mqtt_port', port);

  /// API Base URL — uses cloud URL for caregiver, local for wearer
  String get apiBaseUrl {
    if (isCaregiver && cloudUrl.isNotEmpty) {
      return cloudUrl;
    }
    return 'http://$gatewayIp:8000';
  }

  /// Auto reconnect
  bool get autoReconnect =>
      getSetting<bool>('auto_reconnect', defaultValue: true)!;
  Future<void> setAutoReconnect(bool value) =>
      saveSetting('auto_reconnect', value);

  /// Dark mode
  bool get isDarkMode =>
      getSetting<bool>('dark_mode', defaultValue: false)!;
  Future<void> setDarkMode(bool value) => saveSetting('dark_mode', value);

  /// Notification settings
  bool get notifCritical =>
      getSetting<bool>('notif_critical', defaultValue: true)!;
  bool get notifAlert =>
      getSetting<bool>('notif_alert', defaultValue: true)!;
  bool get notifWatch =>
      getSetting<bool>('notif_watch', defaultValue: false)!;
  Future<void> setNotifCritical(bool v) => saveSetting('notif_critical', v);
  Future<void> setNotifAlert(bool v) => saveSetting('notif_alert', v);
  Future<void> setNotifWatch(bool v) => saveSetting('notif_watch', v);

  /// Quiet hours
  bool get quietHoursEnabled =>
      getSetting<bool>('quiet_hours', defaultValue: true)!;
  Future<void> setQuietHoursEnabled(bool v) =>
      saveSetting('quiet_hours', v);

  /// User ID
  String get userId =>
      getSetting<String>('user_id', defaultValue: 'default')!;
  Future<void> setUserId(String id) => saveSetting('user_id', id);

  /// Auto thresholds
  bool get autoThresholds =>
      getSetting<bool>('auto_thresholds', defaultValue: true)!;
  Future<void> setAutoThresholds(bool v) =>
      saveSetting('auto_thresholds', v);

  /// HR thresholds
  double get hrLow =>
      getSetting<double>('hr_low', defaultValue: 50.0)!;
  double get hrHigh =>
      getSetting<double>('hr_high', defaultValue: 100.0)!;
  Future<void> setHrLow(double v) => saveSetting('hr_low', v);
  Future<void> setHrHigh(double v) => saveSetting('hr_high', v);

  /// Emergency phone
  String get emergencyPhone =>
      getSetting<String>('emergency_phone', defaultValue: '')!;
  Future<void> setEmergencyPhone(String phone) =>
      saveSetting('emergency_phone', phone);

  // ─── Role & Remote Monitoring ───

  /// Vai trò: 'wearer' hoặc 'caregiver'
  String get userRole =>
      getSetting<String>('user_role', defaultValue: '')!;
  Future<void> setUserRole(String role) => saveSetting('user_role', role);

  bool get isWearer => userRole == 'wearer';
  bool get isCaregiver => userRole == 'caregiver';
  bool get hasSelectedRole => userRole.isNotEmpty;

  /// Cloud server URL (cho người giám sát ở xa)
  String get cloudUrl =>
      getSetting<String>('cloud_url', defaultValue: '')!;
  Future<void> setCloudUrl(String url) => saveSetting('cloud_url', url);

  /// ID người được theo dõi (cho caregiver)
  String get monitorTargetId =>
      getSetting<String>('monitor_target_id', defaultValue: '')!;
  Future<void> setMonitorTargetId(String id) =>
      saveSetting('monitor_target_id', id);

  /// Tên người được theo dõi
  String get monitorTargetName =>
      getSetting<String>('monitor_target_name', defaultValue: '')!;
  Future<void> setMonitorTargetName(String name) =>
      saveSetting('monitor_target_name', name);

  /// Mã ghép nối (pairing code)
  String get pairingCode =>
      getSetting<String>('pairing_code', defaultValue: '')!;
  Future<void> setPairingCode(String code) =>
      saveSetting('pairing_code', code);

  /// Onboarding hoàn tất
  bool get onboardingCompleted =>
      getSetting<bool>('onboarding_completed', defaultValue: false)!;
  Future<void> setOnboardingCompleted(bool v) =>
      saveSetting('onboarding_completed', v);

  /// Demo mode
  bool get isDemoMode =>
      getSetting<bool>('demo_mode', defaultValue: true)!; // Mặc định bật để demo
  Future<void> setDemoMode(bool v) => saveSetting('demo_mode', v);

  // ─── Alerts cache ───

  /// Lưu alert đã đọc
  Future<void> markAlertAsRead(String alertId) async {
    await _alertsBoxInstance.put(alertId, true);
  }

  /// Kiểm tra alert đã đọc
  bool isAlertRead(String alertId) {
    return _alertsBoxInstance.get(alertId, defaultValue: false) as bool;
  }

  // ─── Cache ───

  /// Lưu cache JSON
  Future<void> cacheData(String key, dynamic data) async {
    await _cacheBoxInstance.put(key, jsonEncode(data));
    await _cacheBoxInstance.put('${key}_time', DateTime.now().toIso8601String());
  }

  /// Đọc cache JSON
  dynamic getCachedData(String key) {
    final data = _cacheBoxInstance.get(key);
    if (data != null) {
      return jsonDecode(data as String);
    }
    return null;
  }

  /// Kiểm tra cache còn hiệu lực (< maxAge phút)
  bool isCacheValid(String key, {int maxAgeMinutes = 5}) {
    final timeStr = _cacheBoxInstance.get('${key}_time') as String?;
    if (timeStr == null) return false;
    final time = DateTime.parse(timeStr);
    return DateTime.now().difference(time).inMinutes < maxAgeMinutes;
  }

  /// Xóa toàn bộ cache
  Future<void> clearCache() async {
    await _cacheBoxInstance.clear();
  }

  /// Xóa tất cả dữ liệu
  Future<void> clearAll() async {
    await _settingsBoxInstance.clear();
    await _alertsBoxInstance.clear();
    await _cacheBoxInstance.clear();
  }
}
