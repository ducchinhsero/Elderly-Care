import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_model.dart';
import '../services/api_service.dart';
import '../services/mock_data_service.dart';
import '../services/storage_service.dart';
import 'vitals_provider.dart';

/// State cho history data
class HistoryState {
  final HistoryModel? historyData;
  final bool isLoading;
  final String? error;
  final int selectedHours; // 24, 168, 720

  const HistoryState({
    this.historyData,
    this.isLoading = false,
    this.error,
    this.selectedHours = 24,
  });

  HistoryState copyWith({
    HistoryModel? historyData,
    bool? isLoading,
    String? error,
    int? selectedHours,
  }) {
    return HistoryState(
      historyData: historyData ?? this.historyData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedHours: selectedHours ?? this.selectedHours,
    );
  }
}

/// Notifier cho history
class HistoryNotifier extends StateNotifier<HistoryState> {
  final ApiService _apiService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final bool _isDemoMode;

  HistoryNotifier(
    this._apiService,
    this._storageService,
    this._mockDataService, {
    required bool isDemoMode,
  })  : _isDemoMode = isDemoMode,
        super(const HistoryState()) {
    loadHistory();
  }

  /// Tải lịch sử từ API (hoặc mock data)
  Future<void> loadHistory({int? hours}) async {
    final h = hours ?? state.selectedHours;
    state = state.copyWith(isLoading: true, selectedHours: h);

    try {
      dynamic data;
      if (_isDemoMode) {
        // Delay nhẹ để giống API thật
        await Future.delayed(const Duration(milliseconds: 600));
        final points = _mockDataService.generateHistory(hours: h);
        data = {
          'time_range_hours': h,
          'total_points': points.length,
          'start_time': points.last['timestamp'],
          'end_time': points.first['timestamp'],
          'data': points,
        };
      } else {
        data = await _apiService.getHistory(
          hours: h,
          patientId: _effectivePatientId,
        );
      }

      final history = HistoryModel.fromJson(data);

      state = state.copyWith(
        historyData: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Không thể tải lịch sử: $e',
      );
    }
  }

  /// Chuyển khoảng thời gian
  Future<void> setTimeRange(int hours) async {
    await loadHistory(hours: hours);
  }

  /// Refresh
  Future<void> refresh() => loadHistory();

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
}

// ─── Providers ───

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final isDemo = storageService.isDemoMode;

  return HistoryNotifier(
    apiService,
    storageService,
    mockDataService,
    isDemoMode: isDemo,
  );
});
