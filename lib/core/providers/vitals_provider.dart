import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vitals_model.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../services/mock_data_service.dart';

/// State cho vitals data
class VitalsState {
  final VitalsModel? currentVitals;
  final List<VitalsModel> recentHistory; // 30 phút gần nhất cho mini chart
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isTimedOut; // > 60 giây không nhận data

  const VitalsState({
    this.currentVitals,
    this.recentHistory = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isTimedOut = false,
  });

  VitalsState copyWith({
    VitalsModel? currentVitals,
    List<VitalsModel>? recentHistory,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isTimedOut,
  }) {
    return VitalsState(
      currentVitals: currentVitals ?? this.currentVitals,
      recentHistory: recentHistory ?? this.recentHistory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}

class VitalsNotifier extends StateNotifier<VitalsState> {
  final MqttService _mqttService;
  final ApiService _apiService;
  final WebSocketService _wsService;
  final MockDataService _mockDataService;
  final bool _isRemoteMode;
  final bool _isDemoMode;
  StreamSubscription? _mqttSubscription;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _mockSubscription;
  Timer? _timeoutTimer;

  VitalsNotifier(
    this._mqttService,
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
    } else if (_isRemoteMode) {
      _listenToWebSocket();
    } else {
      _listenToMqtt();
    }
    _startTimeoutCheck();
  }

  /// Subscribe Mock vitals stream (demo mode)
  void _listenToMockData() {
    _mockSubscription = _mockDataService.vitalsStream.listen(
      (json) {
        try {
          final vitals = VitalsModel.fromJson(json);
          _updateVitals(vitals);
        } catch (e) {
          state = state.copyWith(error: 'Lỗi parse dữ liệu: $e');
        }
      },
    );
  }

  /// Subscribe MQTT vitals stream (cho người đeo — local)
  void _listenToMqtt() {
    _mqttSubscription = _mqttService.vitalsStream.listen(
      (json) {
        try {
          final vitals = VitalsModel.fromJson(json);
          _updateVitals(vitals);
        } catch (e) {
          state = state.copyWith(error: 'Lỗi parse dữ liệu: $e');
        }
      },
      onError: (e) {
        state = state.copyWith(error: 'Lỗi MQTT: $e');
      },
    );
  }

  /// Subscribe WebSocket vitals stream (cho người giám sát — remote)
  void _listenToWebSocket() {
    _wsSubscription = _wsService.vitalsStream.listen(
      (json) {
        try {
          final vitals = VitalsModel.fromJson(json);
          _updateVitals(vitals);
        } catch (e) {
          state = state.copyWith(error: 'Lỗi parse dữ liệu: $e');
        }
      },
      onError: (e) {
        state = state.copyWith(error: 'Lỗi WebSocket: $e');
      },
    );
  }

  /// Cập nhật vitals mới (chung cho cả 2 mode)
  void _updateVitals(VitalsModel vitals) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 30));

    // Thêm vào recent history và lọc bỏ dữ liệu cũ > 30 phút
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

  /// Kiểm tra timeout (> 60 giây không có data)
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

  /// Pull-to-refresh: fetch từ API
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final json = await _apiService.getLatestVitals();
      final vitals = VitalsModel.fromJson(json);
      _updateVitals(vitals);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải dữ liệu: $e',
      );
    }
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _wsSubscription?.cancel();
    _mockSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════

/// Provider cho StorageService (khai báo ở đây để dùng chung)
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider cho MqttService (singleton)
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider cho ApiService (singleton)
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider cho WebSocketService (singleton)
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider cho user role — đọc từ storage
final userRoleProvider = Provider<String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.userRole;
});

/// Provider kiểm tra có phải caregiver (remote mode) không
final isRemoteModeProvider = Provider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.isCaregiver;
});

/// Provider cho MQTT connection state
final mqttConnectionStateProvider =
    StreamProvider<MqttConnectionState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.connectionStateStream;
});

/// Provider cho WebSocket connection state
final wsConnectionStateProvider =
    StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.connectionStateStream;
});

/// Provider cho MockDataService (singleton)
final mockDataServiceProvider = Provider<MockDataService>((ref) {
  final service = MockDataService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider cho vitals state — tự chọn source dựa vào role và demo mode
final vitalsProvider =
    StateNotifierProvider<VitalsNotifier, VitalsState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  final isRemote = storage.isCaregiver;
  final isDemo = storage.isDemoMode;

  return VitalsNotifier(
    mqttService,
    apiService,
    wsService,
    mockDataService,
    isRemoteMode: isRemote,
    isDemoMode: isDemo,
  );
});

/// Provider tiện ích: chỉ lấy HR hiện tại
final currentHrProvider = Provider<double>((ref) {
  return ref.watch(vitalsProvider).currentVitals?.hrBpm ?? 0.0;
});

/// Provider tiện ích: chỉ lấy alert level hiện tại
final currentAlertLevelProvider = Provider<String>((ref) {
  return ref.watch(vitalsProvider).currentVitals?.alertLevel ?? 'SAFE';
});
