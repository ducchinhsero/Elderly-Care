import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/notification_service.dart';
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
  final NotificationService _notificationService;
  final bool _isDemoMode;
  StreamSubscription? _mockSubscription;
  Timer? _apiPollingTimer;
  final Map<String, DateTime> _lastNotifiedAt = {};
  bool _hasLoadedOnce = false;

  AlertsNotifier(
    this._apiService,
    this._storageService,
    this._mockDataService, {
    required NotificationService notificationService,
    required bool isDemoMode,
  })  : _notificationService = notificationService,
        _isDemoMode = isDemoMode,
        super(const AlertsState()) {
    if (_isDemoMode) {
      _listenToMockAlerts();
      loadAlerts();
    } else {
      loadAlerts();
      _apiPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final beforeIds = byId.keys.toSet();

    for (final alert in incoming) {
      if (!alert.isCritical && _hasRecentDuplicate(byId.values, alert)) {
        continue;
      }
      final wasRead = _storageService.isAlertRead(alert.id) ||
          (byId[alert.id]?.isRead ?? false);
      byId[alert.id] = alert.copyWith(isRead: wasRead);

      if (_hasLoadedOnce && !beforeIds.contains(alert.id)) {
        unawaited(_notifyNewAlert(alert));
      }
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
    _hasLoadedOnce = true;
  }

  bool _hasRecentDuplicate(Iterable<AlertModel> existing, AlertModel incoming) {
    final key = _dedupeKey(incoming);
    return existing.any((alert) {
      if (alert.isCritical) return false;
      return _dedupeKey(alert) == key &&
          (alert.timestamp.difference(incoming.timestamp).abs().inMinutes < 10);
    });
  }

  String _dedupeKey(AlertModel alert) {
    return '${alert.type.toLowerCase()}_${alert.level}_${alert.detail}';
  }

  Future<void> _notifyNewAlert(AlertModel alert) async {
    final level = alert.level.toUpperCase();
    if (level == 'SAFE') return;
    if (!_isNotificationAllowed(alert)) return;

    final key = '${alert.type}_$level';
    final now = DateTime.now();
    final last = _lastNotifiedAt[key];
    final cooldown = alert.isCritical
        ? const Duration(seconds: 30)
        : const Duration(minutes: 5);
    if (last != null && now.difference(last) < cooldown) return;

    _lastNotifiedAt[key] = now;
    await _notificationService.showAlertNotification(
      level: alert.level,
      title: _notificationTitle(alert),
      body: alert.detail.isNotEmpty ? alert.detail : alert.type,
    );
  }

  bool _isNotificationAllowed(AlertModel alert) {
    final level = alert.level.toUpperCase();
    if (level == 'CRITICAL' && !_storageService.notifCritical) return false;
    if (level == 'ALERT' && !_storageService.notifAlert) return false;
    if (level == 'WATCH' && !_storageService.notifWatch) return false;

    if (!_bypassesQuietHours(alert) &&
        _storageService.quietHoursEnabled &&
        _notificationService.isQuietHours()) {
      return false;
    }
    return true;
  }

  bool _bypassesQuietHours(AlertModel alert) {
    final type = alert.type.toLowerCase();
    return alert.isCritical ||
        type.contains('fall') ||
        type.contains('tachy') ||
        type.contains('brady') ||
        type.contains('afib');
  }

  String _notificationTitle(AlertModel alert) {
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
  final notificationService = ref.watch(notificationServiceProvider);

  return AlertsNotifier(
    apiService,
    storageService,
    mockDataService,
    notificationService: notificationService,
    isDemoMode: storageService.isDemoMode,
  );
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).unreadCount;
});
