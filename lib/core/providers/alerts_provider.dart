import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/storage_service.dart';
import 'vitals_provider.dart';

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

class AlertsNotifier extends StateNotifier<AlertsState> {
  final ApiService _apiService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final bool _isDemoMode;
  StreamSubscription? _mockSubscription;
  Timer? _apiPollingTimer;

  AlertsNotifier(
    this._apiService,
    this._storageService,
    this._mockDataService, {
    required bool isDemoMode,
  })  : _isDemoMode = isDemoMode,
        super(const AlertsState()) {
    if (_isDemoMode) {
      _listenToMockAlerts();
      loadAlerts();
    } else {
      loadAlerts();
      _apiPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        loadAlerts(showLoading: false);
      });
    }
  }

  void _listenToMockAlerts() {
    _mockSubscription = _mockDataService.alertStream.listen(
      (json) {
        try {
          _mergeAlerts([AlertModel.fromJson(json)]);
        } catch (e) {
          print('Error parsing mock alert: $e');
        }
      },
    );
  }

  void _mergeAlerts(List<AlertModel> incoming) {
    final byId = <String, AlertModel>{
      for (final alert in state.alerts) alert.id: alert,
    };
    for (final alert in incoming) {
      final wasRead = _storageService.isAlertRead(alert.id) ||
          (byId[alert.id]?.isRead ?? false);
      byId[alert.id] = alert.copyWith(isRead: wasRead);
    }
    final updated = byId.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (updated.length > 200) {
      updated.removeRange(200, updated.length);
    }
    state = state.copyWith(
      alerts: updated,
      isLoading: false,
      unreadCount: updated.where((a) => !a.isRead).length,
      error: null,
    );
  }

  Future<void> loadAlerts({int limit = 80, bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }
    try {
      List<AlertModel> alerts;
      if (_isDemoMode) {
        final data = _mockDataService.generateAlertHistory(count: 15);
        alerts = data.map((json) => AlertModel.fromJson(json)).toList();
      } else {
        final data = await _apiService.getAlerts(limit: limit);
        alerts = data
            .whereType<Map<String, dynamic>>()
            .map(AlertModel.fromJson)
            .toList();
      }
      _mergeAlerts(alerts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải cảnh báo: $e',
      );
    }
  }

  Future<void> markAsRead(String alertId) async {
    await _storageService.markAlertAsRead(alertId);
    final updatedAlerts = state.alerts.map((a) {
      if (a.id == alertId) return a.copyWith(isRead: true);
      return a;
    }).toList();

    state = state.copyWith(
      alerts: updatedAlerts,
      unreadCount: updatedAlerts.where((a) => !a.isRead).length,
    );
  }

  Future<void> markAllAsRead() async {
    for (final a in state.alerts) {
      await _storageService.markAlertAsRead(a.id);
    }
    final updatedAlerts =
        state.alerts.map((a) => a.copyWith(isRead: true)).toList();

    state = state.copyWith(alerts: updatedAlerts, unreadCount: 0);
  }

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
    _mockSubscription?.cancel();
    _apiPollingTimer?.cancel();
    super.dispose();
  }
}

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);

  return AlertsNotifier(
    apiService,
    storageService,
    mockDataService,
    isDemoMode: storageService.isDemoMode,
  );
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).unreadCount;
});
