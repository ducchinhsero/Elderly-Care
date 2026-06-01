import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
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
  final WebSocketService _webSocketService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final NotificationService _notificationService;
  final bool _isDemoMode;
  StreamSubscription? _mockSubscription;
  StreamSubscription? _wsAlertSubscription;
  Timer? _apiPollingTimer;
  Timer? _urgentPollingTimer;
  final Map<String, DateTime> _lastNotifiedAt = {};
  bool _hasLoadedOnce = false;

  AlertsNotifier(
    this._apiService,
    this._webSocketService,
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
      _listenToRealtimeAlerts();
      _urgentPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        loadUrgentAlerts(showLoading: false);
      });
      _apiPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        loadAlerts(showLoading: false);
      });
    }
  }

  void _listenToRealtimeAlerts() {
    if (!_storageService.isCaregiver) return;
    _wsAlertSubscription = _webSocketService.alertsStream.listen(
      (json) {
        try {
          final alerts = _alertsFromRealtimeMessage(json);
          if (alerts.isNotEmpty) {
            _mergeAlerts(alerts);
          }
        } catch (e) {
          state = state.copyWith(error: 'Lá»—i parse cáº£nh bÃ¡o realtime: $e');
        }
      },
      onError: (e) {
        state = state.copyWith(error: 'Lá»—i WebSocket cáº£nh bÃ¡o: $e');
      },
    );
    unawaited(_webSocketService.connectAlerts(
      patientId: _effectivePatientId,
      caregiverId: _effectiveCaregiverId,
    ));
    unawaited(loadUrgentAlerts(showLoading: false));
  }

  List<AlertModel> _alertsFromRealtimeMessage(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    if (type == 'alert_backlog') {
      final items = json['alerts'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AlertModel.fromJson)
          .toList();
    }
    final alert = json['alert'];
    if (alert is Map<String, dynamic>) {
      return [AlertModel.fromJson(alert)];
    }
    return const [];
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
        final urgent = await _apiService.getRealtimeAlerts(
          limit: 50,
          patientId: _effectivePatientId,
        );
        final data = await _apiService.getAlerts(
          limit: limit,
          patientId: _effectivePatientId,
        );
        alerts = data
            .whereType<Map<String, dynamic>>()
            .map(AlertModel.fromJson)
            .toList();
        alerts = [
          ...urgent.whereType<Map<String, dynamic>>().map(AlertModel.fromJson),
          ...alerts,
        ];
      }
      _mergeAlerts(alerts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.alerts.isEmpty
            ? 'Không thể tải cảnh báo: $e'
            : 'Mất kết nối backend, đang giữ danh sách cảnh báo gần nhất.',
      );
    }
  }

  Future<void> loadUrgentAlerts({
    int limit = 50,
    bool showLoading = false,
  }) async {
    if (_isDemoMode) return;
    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final data = await _apiService.getRealtimeAlerts(
        limit: limit,
        patientId: _effectivePatientId,
      );
      final alerts = data
          .whereType<Map<String, dynamic>>()
          .map(AlertModel.fromJson)
          .toList();
      _mergeAlerts(alerts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.alerts.isEmpty
            ? 'KhÃ´ng thá»ƒ táº£i cáº£nh bÃ¡o kháº©n: $e'
            : 'Máº¥t káº¿t ná»‘i cáº£nh bÃ¡o realtime, Ä‘ang giá»¯ dá»¯ liá»‡u gáº§n nháº¥t.',
      );
    }
  }

  Future<void> acknowledgeAlert(String alertId) async {
    final caregiverId = _effectiveCaregiverId;
    try {
      final response = await _apiService.acknowledgeAlert(
        eventId: alertId,
        caregiverId: caregiverId,
        note: 'checked_from_app',
      );
      final ackStatus =
          response['ack_status'] as Map<String, dynamic>? ?? const {};
      await _storageService.markAlertAsRead(alertId);
      final updatedAlerts = state.alerts.map((a) {
        if (a.id == alertId) {
          return a.copyWith(isRead: true, ackStatus: ackStatus);
        }
        return a;
      }).toList();
      state = state.copyWith(
        alerts: updatedAlerts,
        unreadCount: updatedAlerts.where((a) => !a.isRead).length,
      );
    } catch (e) {
      state = state.copyWith(error: 'KhÃ´ng thá»ƒ xÃ¡c nháº­n cáº£nh bÃ¡o: $e');
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
    _wsAlertSubscription?.cancel();
    _apiPollingTimer?.cancel();
    _urgentPollingTimer?.cancel();
    super.dispose();
  }

  String? get _effectivePatientId {
    if (_storageService.isCaregiver &&
        _storageService.monitorTargetId.isNotEmpty) {
      return _storageService.monitorTargetId;
    }
    if (_storageService.isWearer && _storageService.deviceCode.isNotEmpty) {
      return _storageService.deviceCode;
    }
    return null;
  }

  String get _effectiveCaregiverId {
    if (_storageService.userId.isNotEmpty &&
        _storageService.userId != 'default') {
      return _storageService.userId;
    }
    if (_storageService.caregiverName.isNotEmpty) {
      return _storageService.caregiverName;
    }
    return 'caregiver_app';
  }
}

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final webSocketService = ref.watch(webSocketServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return AlertsNotifier(
    apiService,
    webSocketService,
    storageService,
    mockDataService,
    notificationService: notificationService,
    isDemoMode: storageService.isDemoMode,
  );
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).unreadCount;
});
