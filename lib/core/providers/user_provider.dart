import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/mock_data_service.dart';
import 'vitals_provider.dart';

/// State cho user profile
class UserState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;
  final bool isCalibrating;
  final int calibrationSecondsRemaining;

  const UserState({
    this.profile,
    this.isLoading = false,
    this.error,
    this.isCalibrating = false,
    this.calibrationSecondsRemaining = 0,
  });

  UserState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    bool? isCalibrating,
    int? calibrationSecondsRemaining,
  }) {
    return UserState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      calibrationSecondsRemaining:
          calibrationSecondsRemaining ?? this.calibrationSecondsRemaining,
    );
  }
}

/// Notifier cho user profile
class UserNotifier extends StateNotifier<UserState> {
  final ApiService _apiService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final bool _isDemoMode;

  UserNotifier(
    this._apiService,
    this._storageService,
    this._mockDataService, {
    required bool isDemoMode,
  })  : _isDemoMode = isDemoMode,
        super(const UserState()) {
    loadProfile();
  }

  /// Tải profile từ API (hoặc mock data)
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _storageService.userId;
      Map<String, dynamic> json;
      
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 400));
        json = _mockDataService.generateUserProfile();
      } else {
        json = await _apiService.getUserProfile(userId);
      }
      
      final profile = UserProfile.fromJson(json);
      state = state.copyWith(
        profile: profile,
        isLoading: false,
      );
    } catch (e) {
      // Fallback to default profile
      state = state.copyWith(
        profile: UserProfile.empty(),
        isLoading: false,
        error: 'Không thể tải hồ sơ: $e',
      );
    }
  }

  /// Cập nhật profile
  Future<void> updateProfile(UserProfile updated) async {
    state = state.copyWith(profile: updated);
  }

  /// Cập nhật comorbidities
  Future<void> updateComorbidities(List<String> comorbidities) async {
    if (state.profile != null) {
      final updated = state.profile!.copyWith(comorbidities: comorbidities);
      state = state.copyWith(profile: updated);
    }
  }

  /// Bắt đầu calibration
  Future<void> startCalibration() async {
    state = state.copyWith(
      isCalibrating: true,
      calibrationSecondsRemaining: 30 * 60, // 30 phút
    );

    try {
      await _apiService.startCalibration();
      // Countdown sẽ được handle ở widget layer
    } catch (e) {
      state = state.copyWith(
        isCalibrating: false,
        error: 'Không thể bắt đầu calibration: $e',
      );
    }
  }

  /// Cập nhật countdown
  void updateCalibrationCountdown(int secondsRemaining) {
    if (secondsRemaining <= 0) {
      // Calibration hoàn thành
      final updated = state.profile?.copyWith(
        calibration: CalibrationStatus(
          isCalibrated: true,
          calibratedAt: DateTime.now(),
          needsRecalibration: false,
        ),
      );
      state = state.copyWith(
        profile: updated,
        isCalibrating: false,
        calibrationSecondsRemaining: 0,
      );
    } else {
      state = state.copyWith(calibrationSecondsRemaining: secondsRemaining);
    }
  }

  /// Cập nhật emergency contact
  Future<void> updateEmergencyContact(String name, String phone) async {
    if (state.profile != null) {
      final updated = state.profile!.copyWith(
        emergencyContact: EmergencyContact(name: name, phone: phone),
      );
      state = state.copyWith(profile: updated);
      await _storageService.setEmergencyPhone(phone);
    }
  }

  Future<void> refresh() => loadProfile();
}

// ─── Providers ───

final userProvider =
    StateNotifierProvider<UserNotifier, UserState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final isDemo = storageService.isDemoMode;
  
  return UserNotifier(
    apiService, 
    storageService, 
    mockDataService,
    isDemoMode: isDemo,
  );
});
