import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_report_model.dart';
import '../models/vitals_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../utils/alert_notification_policy.dart';

class VitalsState {
  final VitalsModel? currentVitals;
  final HealthReportModel? healthReport;
  final DeviceRuntimeStatus runtimeStatus;
  final List<VitalsModel> recentHistory;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isTimedOut;

  const VitalsState({
    this.currentVitals,
    this.healthReport,
    this.runtimeStatus = const DeviceRuntimeStatus(),
    this.recentHistory = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isTimedOut = false,
  });

  VitalsState copyWith({
    VitalsModel? currentVitals,
    HealthReportModel? healthReport,
    DeviceRuntimeStatus? runtimeStatus,
    List<VitalsModel>? recentHistory,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isTimedOut,
  }) {
    return VitalsState(
      currentVitals: currentVitals ?? this.currentVitals,
      healthReport: healthReport ?? this.healthReport,
      runtimeStatus: runtimeStatus ?? this.runtimeStatus,
      recentHistory: recentHistory ?? this.recentHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}

class DeviceRuntimeStatus {
  final bool backendReachable;
  final String networkMode;
  final String? connectedSsid;
  final bool internetReachable;
  final bool polarRunning;
  final bool polarAutoStart;
  final String? polarAddress;
  final String? polarLastPacketAt;
  final String? polarLastPredictionAt;
  final String? polarLastError;
  final int connectAttempts;
  final int successfulConnections;
  final int reconnectCount;

  const DeviceRuntimeStatus({
    this.backendReachable = false,
    this.networkMode = 'unknown',
    this.connectedSsid,
    this.internetReachable = false,
    this.polarRunning = false,
    this.polarAutoStart = false,
    this.polarAddress,
    this.polarLastPacketAt,
    this.polarLastPredictionAt,
    this.polarLastError,
    this.connectAttempts = 0,
    this.successfulConnections = 0,
    this.reconnectCount = 0,
  });

  factory DeviceRuntimeStatus.fromBackendEnvelope(
    Map<String, dynamic> json, {
    bool backendReachable = true,
  }) {
    final polar = json['polar'] as Map<String, dynamic>? ?? const {};
    final network =
        json['network_provisioning'] as Map<String, dynamic>? ?? const {};
    return DeviceRuntimeStatus(
      backendReachable: backendReachable,
      networkMode: (network['mode'] ?? 'unknown').toString(),
      connectedSsid: network['connected_ssid']?.toString(),
      internetReachable: network['internet_reachable'] == true,
      polarRunning: polar['running'] == true,
      polarAutoStart: polar['auto_start'] == true,
      polarAddress: polar['address']?.toString(),
      polarLastPacketAt: polar['last_packet_at']?.toString(),
      polarLastPredictionAt: polar['last_prediction_at']?.toString(),
      polarLastError: polar['last_error']?.toString(),
      connectAttempts: _statusInt(polar['connect_attempts']),
      successfulConnections: _statusInt(polar['successful_connections']),
      reconnectCount: _statusInt(polar['reconnect_count']),
    );
  }

  bool get hasRecentPolarPacket {
    final parsed = DateTime.tryParse(polarLastPacketAt ?? '');
    if (parsed == null) return false;
    return DateTime.now().difference(parsed).inSeconds <= 90;
  }

  bool get hasRecentPrediction {
    final parsed = DateTime.tryParse(polarLastPredictionAt ?? '');
    if (parsed == null) return false;
    return DateTime.now().difference(parsed).inSeconds <= 90;
  }

  String get polarUserLabel {
    if (!backendReachable) return 'Backend mất kết nối';
    if (!polarRunning) return 'Polar chưa chạy';
    if (hasRecentPrediction) return 'Polar đang thu tín hiệu';
    if (hasRecentPolarPacket) return 'Polar đã kết nối, đang chờ xử lý';
    if ((polarLastError ?? '').isNotEmpty) return 'Polar cần kiểm tra';
    return 'Polar đang kết nối';
  }

  String get networkUserLabel {
    if (!backendReachable) return 'Không kết nối được Raspberry';
    if (networkMode == 'client') {
      final ssid = connectedSsid;
      return ssid == null || ssid.isEmpty
          ? 'Raspberry đã vào Wi-Fi'
          : 'Raspberry đã vào Wi-Fi $ssid';
    }
    if (networkMode == 'ap') return 'Raspberry đang phát Wi-Fi setup';
    if (networkMode == 'offline') return 'Raspberry chưa có Internet';
    return 'Chưa rõ trạng thái mạng Raspberry';
  }
}

int _statusInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class VitalsNotifier extends StateNotifier<VitalsState> {
  static const Duration _freshVitalsWindow = Duration(seconds: 90);

  final ApiService _apiService;
  final WebSocketService _wsService;
  final MqttService _mqttService;
  final MockDataService _mockDataService;
  final StorageService _storageService;
  final NotificationService _notificationService;
  final bool _isRemoteMode;
  final bool _isDemoMode;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _mqttVitalsSubscription;
  StreamSubscription? _mqttAlertSubscription;
  StreamSubscription? _mockSubscription;
  Timer? _timeoutTimer;
  Timer? _apiPollingTimer;
  Timer? _reportTimer;
  Timer? _runtimeStatusTimer;
  bool _isRefreshing = false;
  final Map<String, DateTime> _lastNotifiedAt = {};

  VitalsNotifier(
    this._apiService,
    this._wsService,
    this._mqttService,
    this._mockDataService, {
    required StorageService storageService,
    required NotificationService notificationService,
    required bool isRemoteMode,
    required bool isDemoMode,
  })  : _storageService = storageService,
        _notificationService = notificationService,
        _isRemoteMode = isRemoteMode,
        _isDemoMode = isDemoMode,
        super(const VitalsState()) {
    if (_isDemoMode) {
      _listenToMockData();
      _mockDataService.start();
    } else {
      if (_isRemoteMode) {
        _listenToWebSocket();
      } else {
        _listenToMqtt();
      }
      _startApiPolling();
    }
    _startTimeoutCheck();
  }

  void _listenToMockData() {
    _mockSubscription = _mockDataService.vitalsStream.listen(
      (json) {
        try {
          _updateVitals(VitalsModel.fromJson(json));
        } catch (e) {
          state = state.copyWith(error: 'Lỗi parse dữ liệu demo: $e');
        }
      },
    );
  }

  void _listenToWebSocket() {
    _wsSubscription = _wsService.vitalsStream.listen(
      (json) {
        try {
          final vitals = VitalsModel.fromJson(json);
          _updateVitals(vitals);
        } catch (e) {
          state = state.copyWith(error: 'Lỗi parse WebSocket: $e');
        }
      },
      onError: (e) {
        state = state.copyWith(error: 'Lỗi WebSocket: $e');
      },
    );
    _wsService.connect();
  }

  void _listenToMqtt() {
    _mqttVitalsSubscription = _mqttService.vitalsStream.listen(
      (json) {
        try {
          _updateVitals(VitalsModel.fromJson(json));
        } catch (e) {
          state = state.copyWith(error: 'Lỗi đọc MQTT: $e');
        }
      },
      onError: (e) {
        state = state.copyWith(error: 'Lỗi MQTT: $e');
      },
    );
    _mqttAlertSubscription = _mqttService.alertStream.listen(
      (json) {
        try {
          final vitals = VitalsModel.fromJson(json);
          unawaited(_notifyImmediateAlerts(vitals));
        } catch (_) {
          // Alert payloads are allowed to be partial; REST polling remains the source of truth.
        }
      },
    );
    unawaited(_mqttService.connect());
  }

  void _startApiPolling() {
    refresh();
    _apiPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshLatestVitals();
    });
    _runtimeStatusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshRuntimeStatus();
    });
    _reportTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshHealthReport(patientId: _effectivePatientId);
    });
  }

  void _updateRuntimeStatusFromEnvelope(Map<String, dynamic> json) {
    if (json.containsKey('polar') || json.containsKey('network_provisioning')) {
      state = state.copyWith(
        runtimeStatus: DeviceRuntimeStatus.fromBackendEnvelope(json),
      );
    }
  }

  bool _hasNoLatestResult(Map<String, dynamic> json) {
    return json.containsKey('latest_result') && json['latest_result'] == null;
  }

  bool _hasStaleLatestResult(Map<String, dynamic> json) {
    return json['latest_result_fresh'] == false;
  }

  bool _isFreshVitals(VitalsModel vitals) {
    final age = DateTime.now().difference(vitals.timestamp);
    if (age.isNegative) {
      return age.abs() <= const Duration(minutes: 5);
    }
    return age <= _freshVitalsWindow;
  }

  void _handleNoLatestResult() {
    state = state.copyWith(
      isLoading: false,
      isTimedOut: true,
      error:
          'Chưa có dữ liệu ECG mới từ Polar. Kiểm tra dây đeo hoặc bấm Bật thu Polar.',
    );
  }

  void _handleStaleLatestResult() {
    state = state.copyWith(
      isLoading: false,
      isTimedOut: true,
      error:
          'Dữ liệu ECG đã cũ. Kiểm tra Polar, dây đeo hoặc bấm Bật thu Polar.',
    );
  }

  void _updateVitals(VitalsModel vitals) {
    final now = DateTime.now();
    final isFresh = _isFreshVitals(vitals);
    final cutoff = now.subtract(const Duration(minutes: 30));
    final updatedHistory = [...state.recentHistory, vitals]
        .where((v) => v.timestamp.isAfter(cutoff))
        .toList();

    state = state.copyWith(
      currentVitals: vitals,
      recentHistory: updatedHistory,
      lastUpdated: isFresh ? now : state.lastUpdated,
      isTimedOut: !isFresh,
      isLoading: false,
      error: isFresh
          ? null
          : 'Dữ liệu ECG đã cũ. Kiểm tra Polar, dây đeo hoặc bấm Bật thu Polar.',
    );

    if (isFresh) {
      unawaited(_notifyImmediateAlerts(vitals));
    }
  }

  Future<void> _notifyImmediateAlerts(VitalsModel vitals) async {
    final urgentAlerts =
        vitals.clinicalAlerts.where(_isImmediateClinicalAlert).toList();

    if (urgentAlerts.isEmpty) return;

    for (final alert in urgentAlerts.take(2)) {
      final level = alert.level.toUpperCase();
      final key = '${alert.type}_$level';
      final now = DateTime.now();
      final last = _lastNotifiedAt[key];
      final cooldown = level == 'CRITICAL'
          ? const Duration(seconds: 30)
          : const Duration(minutes: 3);

      if (last != null && now.difference(last) < cooldown) continue;
      if (!_isNotificationAllowed(level, force: _bypassesQuietHours(alert))) {
        continue;
      }

      _lastNotifiedAt[key] = now;
      await _notificationService.showAlertNotification(
        level: level,
        title: _notificationTitle(alert),
        body: alert.detail.isEmpty ? vitals.message : alert.detail,
      );
    }
  }

  bool _isImmediateClinicalAlert(ClinicalAlert alert) {
    return AlertNotificationPolicy.shouldPopup(
      type: alert.type,
      level: alert.level,
    );
  }

  bool _bypassesQuietHours(ClinicalAlert alert) {
    return AlertNotificationPolicy.bypassesQuietHours(
      type: alert.type,
      level: alert.level,
    );
  }

  bool _isNotificationAllowed(String level, {required bool force}) {
    if (level == 'CRITICAL' && !_storageService.notifCritical) return false;
    if (level == 'ALERT' && !_storageService.notifAlert) return false;
    if (level == 'WATCH' && !_storageService.notifWatch) return false;
    if (!force &&
        _storageService.quietHoursEnabled &&
        _notificationService.isQuietHours()) {
      return false;
    }
    return true;
  }

  String _notificationTitle(ClinicalAlert alert) {
    final type = alert.type.toLowerCase();
    if (type.contains('fall')) return 'Cảnh báo té ngã';
    if (type.contains('tachy') || type.contains('brady')) {
      return 'Nhịp tim nguy hiểm';
    }
    if (type.contains('afib') || type.contains('rhythm')) {
      return 'Bất thường nhịp tim';
    }
    return 'Cảnh báo sức khỏe';
  }

  void _startTimeoutCheck() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.lastUpdated != null) {
        final diff = DateTime.now().difference(state.lastUpdated!);
        if (diff.inSeconds > 60 && !state.isTimedOut) {
          state = state.copyWith(isTimedOut: true);
        }
      }
    });
  }

  Future<void> _refreshLatestVitals() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final json = await _apiService.getLatestVitals();
      _updateRuntimeStatusFromEnvelope(json);
      if (_hasNoLatestResult(json)) {
        _handleNoLatestResult();
        return;
      }
      if (_hasStaleLatestResult(json)) {
        _handleStaleLatestResult();
        return;
      }
      _updateVitals(VitalsModel.fromJson(json));
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        runtimeStatus: const DeviceRuntimeStatus(backendReachable: false),
        error: state.currentVitals == null
            ? 'Không thể tải dữ liệu realtime: $e'
            : 'Mất kết nối backend, đang dùng dữ liệu gần nhất.',
      );
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshHealthReport({String? patientId}) async {
    try {
      final json = await _apiService.getHealthReport(patientId: patientId);
      state = state.copyWith(healthReport: HealthReportModel.fromJson(json));
    } catch (e) {
      if (state.healthReport == null) {
        state = state.copyWith(error: 'Không thể tải tóm tắt sức khỏe: $e');
      }
    }
  }

  Future<void> _refreshRuntimeStatus() async {
    try {
      final json = await _apiService.getHealthStatus();
      state = state.copyWith(
        runtimeStatus: DeviceRuntimeStatus.fromBackendEnvelope(json),
      );
    } catch (_) {
      state = state.copyWith(
        runtimeStatus: const DeviceRuntimeStatus(backendReachable: false),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final json = await _apiService.getLatestVitals();
      _updateRuntimeStatusFromEnvelope(json);
      if (_hasNoLatestResult(json)) {
        _handleNoLatestResult();
        unawaited(_refreshRuntimeStatus());
        return;
      }
      if (_hasStaleLatestResult(json)) {
        _handleStaleLatestResult();
        unawaited(_refreshRuntimeStatus());
        return;
      }
      final vitals = VitalsModel.fromJson(json);
      _updateVitals(vitals);
      unawaited(_refreshRuntimeStatus());
      await _refreshHealthReport(
          patientId: _effectivePatientId ?? vitals.patientId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        runtimeStatus: const DeviceRuntimeStatus(backendReachable: false),
        error: state.currentVitals == null
            ? 'Không thể tải dữ liệu: $e'
            : 'Mất kết nối backend, đang dùng dữ liệu gần nhất.',
      );
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _mqttVitalsSubscription?.cancel();
    _mqttAlertSubscription?.cancel();
    _mockSubscription?.cancel();
    _timeoutTimer?.cancel();
    _apiPollingTimer?.cancel();
    _reportTimer?.cancel();
    _runtimeStatusTimer?.cancel();
    super.dispose();
  }

  Future<bool> startPolarCollector() async {
    try {
      final json = await _apiService.startPolarCollector();
      _updateRuntimeStatusFromEnvelope(json);
      await _refreshRuntimeStatus();
      await _refreshLatestVitals();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Không thể bật thu Polar: $e');
      return false;
    }
  }

  String? get _effectivePatientId {
    if (_storageService.isCaregiver &&
        _storageService.monitorTargetId.isNotEmpty) {
      return _storageService.monitorTargetId;
    }
    if (state.currentVitals?.patientId.isNotEmpty == true) {
      return state.currentVitals!.patientId;
    }
    if (_storageService.isWearer && _storageService.deviceCode.isNotEmpty) {
      return _storageService.deviceCode;
    }
    return null;
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final mqttServiceProvider = Provider<MqttService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = MqttService()
    ..configure(
      host: storage.mqttHost,
      port: storage.mqttPort,
      clientId:
          'elder_health_flutter_${storage.userRole.isEmpty ? 'app' : storage.userRole}',
    );
  ref.onDispose(() => service.dispose());
  return service;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiService()
    ..configure(
      baseUrl: storage.apiBaseUrl,
      apiKey: storage.apiKey,
      accessCode: storage.isCaregiver ? storage.pairingCode : null,
      deviceCode: storage.isWearer ? storage.deviceCode : null,
    );
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = WebSocketService()
    ..configure(
      serverUrl: storage.apiBaseUrl,
      apiKey: storage.apiKey,
      accessCode: storage.isCaregiver ? storage.pairingCode : null,
    );
  ref.onDispose(() => service.dispose());
  return service;
});

final userRoleProvider = Provider<String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.userRole;
});

final isRemoteModeProvider = Provider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.isCaregiver;
});

final mqttConnectionStateProvider = StreamProvider<MqttConnectionState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.connectionStateStream;
});

final wsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.connectionStateStream;
});

final mockDataServiceProvider = Provider<MockDataService>((ref) {
  final service = MockDataService();
  ref.onDispose(() => service.dispose());
  return service;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  unawaited(service.init());
  ref.onDispose(() => service.dispose());
  return service;
});

final vitalsProvider =
    StateNotifierProvider<VitalsNotifier, VitalsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  final mqttService = ref.watch(mqttServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return VitalsNotifier(
    apiService,
    wsService,
    mqttService,
    mockDataService,
    storageService: storage,
    notificationService: notificationService,
    isRemoteMode: storage.isCaregiver,
    isDemoMode: storage.isDemoMode,
  );
});

final currentHrProvider = Provider<double>((ref) {
  return ref.watch(vitalsProvider).currentVitals?.hrBpm ?? 0.0;
});

final currentAlertLevelProvider = Provider<String>((ref) {
  return ref.watch(vitalsProvider).currentVitals?.alertLevel ?? 'SAFE';
});
