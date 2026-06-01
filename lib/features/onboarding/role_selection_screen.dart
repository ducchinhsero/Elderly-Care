import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/services/storage_service.dart';

/// Onboarding starts from a manual code because the edge device processes data locally.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  final _codeController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController(text: '65');
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _caregiverNameController = TextEditingController();
  final _targetNameController = TextEditingController();

  String _selectedRole = 'wearer';
  int _step = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _codeController,
      _apiKeyController,
      _fullNameController,
      _ageController,
      _emergencyNameController,
      _emergencyPhoneController,
      _caregiverNameController,
      _targetNameController,
    ]) {
      controller.addListener(_refreshCanContinue);
    }
    _hydrateSavedValues();
  }

  @override
  void dispose() {
    for (final controller in [
      _codeController,
      _apiKeyController,
      _fullNameController,
      _ageController,
      _emergencyNameController,
      _emergencyPhoneController,
      _caregiverNameController,
      _targetNameController,
    ]) {
      controller.removeListener(_refreshCanContinue);
    }
    _codeController.dispose();
    _apiKeyController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _caregiverNameController.dispose();
    _targetNameController.dispose();
    super.dispose();
  }

  void _refreshCanContinue() {
    if (mounted) setState(() {});
  }

  void _hydrateSavedValues() {
    final storage = ref.read(storageServiceProvider);
    if (storage.userRole == 'wearer' || storage.userRole == 'caregiver') {
      _selectedRole = storage.userRole;
    }

    _codeController.text =
        _selectedRole == 'caregiver' ? storage.pairingCode : storage.deviceCode;
    _apiKeyController.text = storage.apiKey;
    _fullNameController.text = storage.userDisplayName;
    if (storage.userAge > 0) {
      _ageController.text = storage.userAge.toString();
    }
    _emergencyNameController.text = storage.emergencyName;
    _emergencyPhoneController.text = storage.emergencyPhone;
    _caregiverNameController.text = storage.caregiverName;
    _targetNameController.text = storage.monitorTargetName;
  }

  void _selectRole(String role) {
    final storage = ref.read(storageServiceProvider);
    final savedCode =
        role == 'caregiver' ? storage.pairingCode : storage.deviceCode;
    setState(() {
      _selectedRole = role;
      if (savedCode.isNotEmpty) {
        _codeController.text = savedCode;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _step == 0
        ? AppStrings.roleSelectionTitle
        : (_selectedRole == 'wearer'
            ? AppStrings.wearerSetupTitle
            : AppStrings.caregiverSetupTitle);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _Header(title: title, step: _step),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == 0
                    ? _buildCodeStep(context)
                    : _buildInfoStep(context),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  if (_step == 1) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSaving ? null : () => setState(() => _step = 0),
                        child: const Text(AppStrings.back),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          _canContinue && !_isSaving ? _onContinue : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _step == 0 ? Icons.arrow_forward : Icons.check),
                      label: Text(
                        _step == 0 ? AppStrings.continueBtn : 'Hoàn tất',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    final isWearer = _selectedRole == 'wearer';

    return Column(
      key: const ValueKey('code-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.roleSelectionSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _RoleCard(
          icon: Icons.sensors,
          title: AppStrings.roleWearer,
          description: AppStrings.roleWearerDesc,
          color: AppColors.safe,
          isSelected: isWearer,
          onTap: () => _selectRole('wearer'),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.visibility,
          title: AppStrings.roleCaregiver,
          description: AppStrings.roleCaregiverDesc,
          color: AppColors.primary,
          isSelected: !isWearer,
          onTap: () => _selectRole('caregiver'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: isWearer ? AppStrings.deviceCode : AppStrings.accessCode,
            hintText: isWearer
                ? AppStrings.deviceCodeHint
                : AppStrings.accessCodeHint,
            helperText: isWearer
                ? 'Mã này được dán trên Raspberry hoặc thiết bị đeo.'
                : 'Mã do người đeo hoặc hệ thống cấp quyền gửi cho bạn.',
            prefixIcon: Icon(isWearer ? Icons.memory : Icons.vpn_key_outlined),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            UpperCaseTextFormatter(),
          ],
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          decoration: const InputDecoration(
            labelText: 'API key backend',
            helperText: 'Để trống nếu backend chưa bật xác thực API.',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          obscureText: true,
        ),
        if (isWearer) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/lan-setup'),
            icon: const Icon(Icons.settings_ethernet),
            label: const Text('Kết nối Raspberry qua LAN'),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoStep(BuildContext context) {
    if (_selectedRole == 'caregiver') {
      return Column(
        key: const ValueKey('caregiver-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoBanner(
            icon: Icons.cloud_sync_outlined,
            text:
                'Raspberry xử lý tín hiệu tại chỗ, gửi dữ liệu đã xử lý lên cloud. App dùng mã truy cập để đồng bộ dữ liệu từ xa.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _caregiverNameController,
            decoration: const InputDecoration(
              labelText: AppStrings.caregiverName,
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetNameController,
            decoration: const InputDecoration(
              labelText: AppStrings.monitoringTarget,
              hintText: 'Ví dụ: Ông Nguyễn Văn A',
              prefixIcon: Icon(Icons.elderly),
            ),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('wearer-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoBanner(
          icon: Icons.health_and_safety_outlined,
          text:
              'Thiết bị edge sẽ cảnh báo tại chỗ khi có té ngã hoặc nhịp tim nguy hiểm, sau đó đồng bộ dữ liệu lên cloud.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            labelText: AppStrings.name,
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ageController,
          decoration: const InputDecoration(
            labelText: AppStrings.age,
            prefixIcon: Icon(Icons.cake_outlined),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emergencyNameController,
          decoration: const InputDecoration(
            labelText: AppStrings.emergencyName,
            prefixIcon: Icon(Icons.contact_emergency_outlined),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emergencyPhoneController,
          decoration: const InputDecoration(
            labelText: AppStrings.emergencyPhone,
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  bool get _canContinue {
    if (_step == 0) {
      return _codeController.text.trim().length >= 4;
    }
    if (_selectedRole == 'wearer') {
      return _fullNameController.text.trim().isNotEmpty &&
          _ageController.text.trim().isNotEmpty &&
          _emergencyPhoneController.text.trim().isNotEmpty;
    }
    return _caregiverNameController.text.trim().isNotEmpty &&
        _targetNameController.text.trim().isNotEmpty;
  }

  Future<void> _onContinue() async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final code = _codeController.text.trim().toUpperCase();

      await storage.setUserRole(_selectedRole);
      await storage.setApiKey(_apiKeyController.text.trim());
      if (_selectedRole == 'wearer') {
        await _saveWearerInfo(storage, code);
      } else {
        await _saveCaregiverInfo(storage, code);
      }

      await storage.setOnboardingCompleted(true);

      ref.read(apiServiceProvider).configure(
            baseUrl: storage.apiBaseUrl,
            apiKey: storage.apiKey,
            accessCode: storage.isCaregiver ? storage.pairingCode : null,
            deviceCode: storage.isWearer ? storage.deviceCode : null,
          );
      if (storage.isCaregiver) {
        final wsService = ref.read(webSocketServiceProvider);
        wsService.configure(
          serverUrl: storage.apiBaseUrl,
          apiKey: storage.apiKey,
          accessCode: storage.pairingCode,
        );
        wsService.connect();
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể hoàn tất cài đặt: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveWearerInfo(StorageService storage, String code) async {
    final age = int.tryParse(_ageController.text.trim()) ?? 65;
    final fullName = _fullNameController.text.trim();
    final emergencyName = _emergencyNameController.text.trim();
    final emergencyPhone = _emergencyPhoneController.text.trim();
    final repository = ref.read(userProfileRepositoryProvider);
    final existing = await repository.getProfile(code);
    final profile = (existing ?? UserProfile.empty()).copyWith(
      uid: code,
      fullName: fullName,
      dateOfBirth: DateTime.now().subtract(Duration(days: age * 365)),
      gender: existing?.gender ?? 'unknown',
      emergencyContactName: emergencyName,
      emergencyContactPhone: emergencyPhone,
    );

    await storage.setDeviceCode(code);
    await storage.setUserId(code);
    await storage.setUserDisplayName(fullName);
    await storage.setUserAge(age);
    await storage.setEmergencyName(emergencyName);
    await storage.setEmergencyPhone(emergencyPhone);
    await storage.setMonitorTargetId(code);
    await storage.setMonitorTargetName(fullName);
    await repository.saveProfile(profile);
  }

  Future<void> _saveCaregiverInfo(StorageService storage, String code) async {
    final caregiverName = _caregiverNameController.text.trim();
    final targetName = _targetNameController.text.trim();
    final caregiverUserId = 'caregiver_$code';
    final repository = ref.read(userProfileRepositoryProvider);
    final existing = await repository.getProfile(caregiverUserId);
    final profile = (existing ?? UserProfile.empty()).copyWith(
      uid: caregiverUserId,
      fullName: caregiverName,
      gender: existing?.gender ?? 'unknown',
    );

    await storage.setPairingCode(code);
    await storage.setUserId(caregiverUserId);
    await storage.setUserDisplayName(caregiverName);
    await storage.setCaregiverName(caregiverName);
    await storage.setMonitorTargetId(code);
    await storage.setMonitorTargetName(targetName);
    await repository.saveProfile(profile);
  }
}

class _Header extends StatelessWidget {
  final String title;
  final int step;

  const _Header({required this.title, required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Icon(
            step == 0 ? Icons.key_outlined : Icons.assignment_ind_outlined,
            size: 42,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
