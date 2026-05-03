import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/mock_data_service.dart';
import 'vitals_provider.dart';

/// State cho alerts
class AlertsState {
  final List<AlertModel> alerts;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const AlertsState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  AlertsState copyWith({
    List<AlertModel>? alerts,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Notifier quản lý alerts
class AlertsNotifier extends StateNotifier<AlertsState> {
  final MqttService _mqttService;
  final ApiService _apiService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final bool _isDemoMode;
  StreamSubscription? _mqttSubscription;
  StreamSubscription? _mockSubscription;

  AlertsNotifier(
    this._mqttService,
    this._apiService,
    this._storageService,
    this._mockDataService, {
    required bool isDemoMode,
  })  : _isDemoMode = isDemoMode,
        super(const AlertsState()) {
    if (_isDemoMode) {
      _listenToMockAlerts();
    } else {
      _listenToMqttAlerts();
    }
    loadAlerts();
  }

  /// Subscribe Mock alert stream
  void _listenToMockAlerts() {
    _mockSubscription = _mockDataService.alertStream.listen(
      (json) {
        try {
          final alert = AlertModel.fromJson(json);
          _addAlert(alert);
        } catch (e) {
          print('Error parsing mock alert: $e');
        }
      },
    );
  }

  /// Subscribe MQTT alert stream
  void _listenToMqttAlerts() {
    _mqttSubscription = _mqttService.alertStream.listen(
      (json) {
        try {
          final alert = AlertModel.fromJson(json);
          _addAlert(alert);
        } catch (e) {
          print('Error parsing MQTT alert: $e');
        }
      },
    );
  }

  /// Thêm alert mới vào đầu list
  void _addAlert(AlertModel alert) {
    final updatedAlerts = [alert, ...state.alerts];
    // Giữ tối đa 200 alerts
    if (updatedAlerts.length > 200) {
      updatedAlerts.removeRange(200, updatedAlerts.length);
    }

    final unreadCount = updatedAlerts.where((a) => !a.isRead).length;

    state = state.copyWith(
      alerts: updatedAlerts,
      unreadCount: unreadCount,
    );
  }

  /// Tải alerts từ API (hoặc mock data)
  Future<void> loadAlerts({int limit = 50}) async {
    state = state.copyWith(isLoading: true);
    try {
      List<AlertModel> alerts;
      
      if (_isDemoMode) {
        // Load mock history
        final data = _mockDataService.generateAlertHistory(count: 15);
        alerts = data.map((json) => AlertModel.fromJson(json)).toList();
      } else {
        // Load real API
        final data = await _apiService.getAlerts(limit: limit);
        alerts = data.map((json) => AlertModel.fromJson(json as Map<String, dynamic>)).toList();
      }

      // Đánh dấu đã đọc nếu có trong local storage
      final markedAlerts = alerts.map((a) {
        if (_storageService.isAlertRead(a.id)) {
          return a.copyWith(isRead: true);
        }
        return a;
      }).toList();

      // Sort by timestamp descending (mới nhất trước)
      markedAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final unreadCount = markedAlerts.where((a) => !a.isRead).length;

      state = state.copyWith(
        alerts: markedAlerts,
        isLoading: false,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải cảnh báo: $e',
      );
    }
  }

  /// Đánh dấu alert đã đọc
  Future<void> markAsRead(String alertId) async {
    await _storageService.markAlertAsRead(alertId);
    final updatedAlerts = state.alerts.map((a) {
      if (a.id == alertId) return a.copyWith(isRead: true);
      return a;
    }).toList();

    final unreadCount = updatedAlerts.where((a) => !a.isRead).length;

    state = state.copyWith(
      alerts: updatedAlerts,
      unreadCount: unreadCount,
    );
  }

  /// Đánh dấu tất cả đã đọc
  Future<void> markAllAsRead() async {
    for (final a in state.alerts) {
      await _storageService.markAlertAsRead(a.id);
    }
    final updatedAlerts =
        state.alerts.map((a) => a.copyWith(isRead: true)).toList();

    state = state.copyWith(
      alerts: updatedAlerts,
      unreadCount: 0,
    );
  }

  /// Lọc alerts theo thời gian
  List<AlertModel> getNewAlerts() {
    return state.alerts.where((a) => !a.isRead).toList();
  }

  List<AlertModel> getTodayAlerts() {
    final today = DateTime.now();
    return state.alerts.where((a) {
      return a.timestamp.year == today.year &&
          a.timestamp.month == today.month &&
          a.timestamp.day == today.day;
    }).toList();
  }

  List<AlertModel> getLast7DaysAlerts() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return state.alerts.where((a) => a.timestamp.isAfter(cutoff)).toList();
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _mockSubscription?.cancel();
    super.dispose();
  }
}

// ─── Providers ───
// storageServiceProvider đã khai báo trong vitals_provider.dart

/// Provider cho AlertsNotifier
final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final isDemo = storageService.isDemoMode;
  
  return AlertsNotifier(
    mqttService, 
    apiService, 
    storageService, 
    mockDataService,
    isDemoMode: isDemo,
  );
});

/// Provider tiện ích: số alerts chưa đọc
final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).unreadCount;
});
