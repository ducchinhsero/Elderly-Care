import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
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
  final _caregiverNameController = TextEditingController();
  final _targetNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accessCodeController.addListener(_refreshCanContinue);
    _caregiverNameController.addListener(_refreshCanContinue);
    _targetNameController.addListener(_refreshCanContinue);
    final storage = ref.read(storageServiceProvider);
    _accessCodeController.text = storage.pairingCode;
    _caregiverNameController.text = storage.caregiverName;
    _targetNameController.text = storage.monitorTargetName;
  }

  @override
  void dispose() {
    _accessCodeController.removeListener(_refreshCanContinue);
    _caregiverNameController.removeListener(_refreshCanContinue);
    _targetNameController.removeListener(_refreshCanContinue);
    _accessCodeController.dispose();
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
                      'Không cần nhập địa chỉ cloud. Raspberry gửi dữ liệu đã xử lý lên server hệ thống; bạn chỉ cần mã truy cập được cấp quyền.',
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
      await storage.setPairingCode(_accessCodeController.text.trim());
      await storage.setCaregiverName(_caregiverNameController.text.trim());
      await storage.setMonitorTargetName(_targetNameController.text.trim());
      await storage.setOnboardingCompleted(true);

      ref.read(apiServiceProvider).configure(
            baseUrl: storage.apiBaseUrl,
            accessCode: storage.pairingCode,
          );
      final wsService = ref.read(webSocketServiceProvider);
      wsService.configure(
        serverUrl: storage.apiBaseUrl,
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
