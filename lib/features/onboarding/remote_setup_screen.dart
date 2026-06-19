import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/vitals_provider.dart';
import 'role_selection_screen.dart';

/// Backup route for remote caregiver setup. The cloud URL is not user-facing.
class RemoteSetupScreen extends ConsumerStatefulWidget {
  const RemoteSetupScreen({super.key});

  @override
  ConsumerState<RemoteSetupScreen> createState() => _RemoteSetupScreenState();
}

class _RemoteSetupScreenState extends ConsumerState<RemoteSetupScreen> {
  final _accessCodeController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _caregiverNameController = TextEditingController();
  final _targetNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accessCodeController.addListener(_refreshCanContinue);
    _serverUrlController.addListener(_refreshCanContinue);
    _apiKeyController.addListener(_refreshCanContinue);
    _caregiverNameController.addListener(_refreshCanContinue);
    _targetNameController.addListener(_refreshCanContinue);
    final storage = ref.read(storageServiceProvider);
    _accessCodeController.text = storage.pairingCode;
    _serverUrlController.text =
        storage.cloudUrl.isNotEmpty ? storage.cloudUrl : 'elderlycare.local:8000';
    _apiKeyController.text = storage.apiKey;
    _caregiverNameController.text = storage.caregiverName;
    _targetNameController.text = storage.monitorTargetName;
  }

  @override
  void dispose() {
    _accessCodeController.removeListener(_refreshCanContinue);
    _serverUrlController.removeListener(_refreshCanContinue);
    _apiKeyController.removeListener(_refreshCanContinue);
    _caregiverNameController.removeListener(_refreshCanContinue);
    _targetNameController.removeListener(_refreshCanContinue);
    _accessCodeController.dispose();
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _caregiverNameController.dispose();
    _targetNameController.dispose();
    super.dispose();
  }

  void _refreshCanContinue() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối người giám sát'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/role-selection'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nhập địa chỉ Raspberry/server để theo dõi. Nếu cùng mạng Wi-Fi với Raspberry, dùng elderlycare.local hoặc IP của Pi. Khi có cloud, nhập URL cloud đầy đủ.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ Pi / Server',
                helperText:
                    'elderlycare.local, IP LAN, host:port hoặc URL cloud đầy đủ',
                prefixIcon: Icon(Icons.router_outlined),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accessCodeController,
              decoration: const InputDecoration(
                labelText: AppStrings.accessCode,
                hintText: AppStrings.accessCodeHint,
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                UpperCaseTextFormatter(),
              ],
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API key backend',
                helperText: 'Để trống nếu backend chưa bật xác thực API.',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _caregiverNameController,
              decoration: const InputDecoration(
                labelText: AppStrings.caregiverName,
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetNameController,
              decoration: const InputDecoration(
                labelText: AppStrings.monitoringTarget,
                hintText: 'Ví dụ: Ông Nguyễn Văn A',
                prefixIcon: Icon(Icons.elderly),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _canContinue && !_isSaving ? _onSave : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Hoàn tất cài đặt'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canContinue =>
      _accessCodeController.text.trim().length >= 4 &&
      _caregiverNameController.text.trim().isNotEmpty &&
      _targetNameController.text.trim().isNotEmpty;

  Future<void> _onSave() async {
    setState(() => _isSaving = true);
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.setUserRole('caregiver');
      final code = _accessCodeController.text.trim().toUpperCase();
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
      await storage.setCloudUrl(_serverUrlController.text.trim());
      await storage.setApiKey(_apiKeyController.text.trim());
      await storage.setUserId(caregiverUserId);
      await storage.setUserDisplayName(caregiverName);
      await storage.setCaregiverName(caregiverName);
      await storage.setMonitorTargetId(code);
      await storage.setMonitorTargetName(targetName);
      await repository.saveProfile(profile);
      await storage.setOnboardingCompleted(true);

      ref.read(apiServiceProvider).configure(
            baseUrl: storage.apiBaseUrl,
            apiKey: storage.apiKey,
            accessCode: storage.pairingCode,
          );
      final wsService = ref.read(webSocketServiceProvider);
      wsService.configure(
        serverUrl: storage.apiBaseUrl,
        apiKey: storage.apiKey,
        accessCode: storage.pairingCode,
      );
      wsService.connect();

      if (!mounted) return;
      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
