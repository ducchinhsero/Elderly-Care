import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_report_model.dart';
import '../models/vitals_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/mqtt_service.dart';
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
  final bool _isRemoteMode;
  final bool _isDemoMode;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _mockSubscription;
  Timer? _timeoutTimer;
  Timer? _apiPollingTimer;
  Timer? _reportTimer;
  bool _isRefreshing = false;

  VitalsNotifier(
    this._apiService,
    this._wsService,
    this._mockDataService, {
    required bool isRemoteMode,
    required bool isDemoMode,
  })  : _isRemoteMode = isRemoteMode,
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
  return ApiService()..configure(baseUrl: storage.apiBaseUrl);
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = WebSocketService()..configure(serverUrl: storage.apiBaseUrl);
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

final mqttConnectionStateProvider =
    StreamProvider<MqttConnectionState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.connectionStateStream;
});

final wsConnectionStateProvider =
    StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.connectionStateStream;
});

final mockDataServiceProvider = Provider<MockDataService>((ref) {
  final service = MockDataService();
  ref.onDispose(() => service.dispose());
  return service;
});

final vitalsProvider =
    StateNotifierProvider<VitalsNotifier, VitalsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final storage = ref.watch(storageServiceProvider);

  return VitalsNotifier(
    apiService,
    wsService,
    mockDataService,
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
