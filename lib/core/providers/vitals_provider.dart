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

class VitalsState {
  final VitalsModel? currentVitals;
  final HealthReportModel? healthReport;
  final List<VitalsModel> recentHistory;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isTimedOut;

  const VitalsState({
    this.currentVitals,
    this.healthReport,
    this.recentHistory = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isTimedOut = false,
  });

  VitalsState copyWith({
    VitalsModel? currentVitals,
    HealthReportModel? healthReport,
    List<VitalsModel>? recentHistory,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isTimedOut,
  }) {
    return VitalsState(
      currentVitals: currentVitals ?? this.currentVitals,
      healthReport: healthReport ?? this.healthReport,
      recentHistory: recentHistory ?? this.recentHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}

class VitalsNotifier extends StateNotifier<VitalsState> {
  final ApiService _apiService;
  final WebSocketService _wsService;
  final MockDataService _mockDataService;
  final StorageService _storageService;
  final NotificationService _notificationService;
  final bool _isRemoteMode;
  final bool _isDemoMode;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _mockSubscription;
  Timer? _timeoutTimer;
  Timer? _apiPollingTimer;
  Timer? _reportTimer;
  bool _isRefreshing = false;
  final Map<String, DateTime> _lastNotifiedAt = {};

  VitalsNotifier(
    this._apiService,
    this._wsService,
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

  void _startApiPolling() {
    refresh();
    _apiPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshLatestVitals();
    });
    _reportTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshHealthReport(patientId: state.currentVitals?.patientId);
    });
  }

  void _updateVitals(VitalsModel vitals) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 30));
    final updatedHistory = [...state.recentHistory, vitals]
        .where((v) => v.timestamp.isAfter(cutoff))
        .toList();

    state = state.copyWith(
      currentVitals: vitals,
      recentHistory: updatedHistory,
      lastUpdated: now,
      isTimedOut: false,
      isLoading: false,
      error: null,
    );

    unawaited(_notifyImmediateAlerts(vitals));
  }

  Future<void> _notifyImmediateAlerts(VitalsModel vitals) async {
    final urgentAlerts =
        vitals.clinicalAlerts.where(_isImmediateClinicalAlert).toList();

    if (urgentAlerts.isEmpty && !vitals.isCritical) return;

    final alerts = urgentAlerts.isNotEmpty
        ? urgentAlerts
        : [
            ClinicalAlert(
              type: 'critical_vitals',
              level: vitals.alertLevel,
              detail: vitals.message,
            )
          ];

    for (final alert in alerts.take(2)) {
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
    final type = alert.type.toLowerCase();
    final level = alert.level.toUpperCase();
    final isFall = type.contains('fall');
    final isDangerousHeart = type.contains('tachy') ||
        type.contains('brady') ||
        type.contains('afib') ||
        type.contains('rhythm');

    return isFall ||
        level == 'CRITICAL' ||
        (isDangerousHeart && (level == 'ALERT' || level == 'CRITICAL'));
  }

  bool _bypassesQuietHours(ClinicalAlert alert) {
    final type = alert.type.toLowerCase();
    return alert.level.toUpperCase() == 'CRITICAL' ||
        type.contains('fall') ||
        type.contains('tachy') ||
        type.contains('brady') ||
        type.contains('afib');
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
      _updateVitals(VitalsModel.fromJson(json));
    } catch (e) {
      state = state.copyWith(error: 'Không thể tải dữ liệu realtime: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshHealthReport({String? patientId}) async {
    try {
      final json = await _apiService.getHealthReport(patientId: patientId);
      state = state.copyWith(healthReport: HealthReportModel.fromJson(json));
    } catch (e) {
      state = state.copyWith(error: 'Không thể tải báo cáo sức khỏe: $e');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final json = await _apiService.getLatestVitals();
      final vitals = VitalsModel.fromJson(json);
      _updateVitals(vitals);
      await _refreshHealthReport(patientId: vitals.patientId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải dữ liệu: $e',
      );
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _mockSubscription?.cancel();
    _timeoutTimer?.cancel();
    _apiPollingTimer?.cancel();
    _reportTimer?.cancel();
    super.dispose();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  ref.onDispose(() => service.dispose());
  return service;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiService()
    ..configure(
      baseUrl: storage.apiBaseUrl,
      accessCode: storage.isCaregiver ? storage.pairingCode : null,
      deviceCode: storage.isWearer ? storage.deviceCode : null,
    );
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = WebSocketService()
    ..configure(
      serverUrl: storage.apiBaseUrl,
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
  final mockDataService = ref.watch(mockDataServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return VitalsNotifier(
    apiService,
    wsService,
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
