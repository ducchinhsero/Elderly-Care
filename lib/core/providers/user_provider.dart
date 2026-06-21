import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/mock_data_service.dart';
import '../repositories/user_profile_repository.dart';
import 'vitals_provider.dart';

/// State cho user profile
class UserState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const UserState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier cho user profile
class UserNotifier extends StateNotifier<UserState> {
  final ApiService _apiService;
  final StorageService _storageService;
  final MockDataService _mockDataService;
  final UserProfileRepository _repository;
  final bool _isDemoMode;

  UserNotifier(
    this._apiService,
    this._storageService,
    this._mockDataService,
    this._repository, {
    required bool isDemoMode,
  })  : _isDemoMode = isDemoMode,
        super(const UserState()) {
    loadProfile();
  }

  /// Tải profile từ DB local hoặc mock data/API
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _storageService.userId;

      // Load local first
      var profile = await _repository.getProfile(userId);

      if (profile == null) {
        if (_isDemoMode) {
          await Future.delayed(const Duration(milliseconds: 400));
          final json = _mockDataService.generateUserProfile();
          profile = UserProfile.fromJson(json);
          profile.uid = userId;
        } else {
          try {
            final json = await _apiService.getUserProfile(userId);
            profile = UserProfile.fromJson(json);
            profile.uid = userId;
          } catch (e) {
            profile = UserProfile.empty().copyWith(uid: userId);
          }
        }
        await _repository.saveProfile(profile);
      }

      await _syncProfileToSettings(profile);
      state = state.copyWith(
        profile: profile,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        profile: UserProfile.empty(),
        isLoading: false,
        error: 'Không thể tải hồ sơ: $e',
      );
    }
  }

  /// Cập nhật profile
  Future<void> updateProfile(UserProfile updated) async {
    await _repository.saveProfile(updated);
    await _syncProfileToSettings(updated);
    state = state.copyWith(profile: updated);
  }

  /// Cập nhật comorbidities
  Future<void> updateComorbidities(List<String> comorbidities) async {
    if (state.profile != null) {
      final updated = state.profile!.copyWith(comorbidities: comorbidities);
      await _repository.saveProfile(updated);
      state = state.copyWith(profile: updated);
    }
  }

  /// Cập nhật emergency contact
  Future<void> updateEmergencyContact(String name, String phone) async {
    if (state.profile != null) {
      final updated = state.profile!.copyWith(
        emergencyContactName: name,
        emergencyContactPhone: phone,
      );
      await _repository.saveProfile(updated);
      state = state.copyWith(profile: updated);
      await _storageService.setEmergencyName(name);
      await _storageService.setEmergencyPhone(phone);
    }
  }

  Future<void> refresh() => loadProfile();

  Future<void> _syncProfileToSettings(UserProfile profile) async {
    await _storageService.setUserDisplayName(profile.fullName);
    await _storageService.setUserAge(profile.age);
    await _storageService.setEmergencyName(profile.emergencyContactName ?? '');
    await _storageService
        .setEmergencyPhone(profile.emergencyContactPhone ?? '');

    if (_storageService.isWearer) {
      await _storageService.setMonitorTargetId(profile.uid);
      await _storageService.setMonitorTargetName(profile.fullName);
    } else if (_storageService.isCaregiver) {
      await _storageService.setCaregiverName(profile.fullName);
    }
  }
}

// ─── Providers ───

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  throw UnimplementedError(
      'Tạo repository trong main() và override provider này');
});

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final mockDataService = ref.watch(mockDataServiceProvider);
  final repository = ref.watch(userProfileRepositoryProvider);
  final isDemo = storageService.isDemoMode;

  return UserNotifier(
    apiService,
    storageService,
    mockDataService,
    repository,
    isDemoMode: isDemo,
  );
});
