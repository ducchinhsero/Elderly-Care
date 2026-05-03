import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/vitals_provider.dart';

/// Màn hình cấu hình kết nối từ xa cho người giám sát
class RemoteSetupScreen extends ConsumerStatefulWidget {
  const RemoteSetupScreen({super.key});

  @override
  ConsumerState<RemoteSetupScreen> createState() => _RemoteSetupScreenState();
}

class _RemoteSetupScreenState extends ConsumerState<RemoteSetupScreen> {
  final _urlController = TextEditingController();
  final _targetNameController = TextEditingController();
  final _pairingCodeController = TextEditingController();
  bool _isTesting = false;
  bool? _testResult;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _urlController.text = storage.cloudUrl;
    _targetNameController.text = storage.monitorTargetName;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _targetNameController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình theo dõi từ xa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/role-selection'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nhập địa chỉ server cloud mà hệ thống Jetson Nano gửi dữ liệu lên. '
                      'Bạn sẽ nhận được dữ liệu theo thời gian thực qua internet.',
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
            const SizedBox(height: 32),

            // Cloud server URL
            Text(
              AppStrings.cloudServerUrl,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: AppStrings.cloudServerHint,
                prefixIcon: const Icon(Icons.cloud_outlined),
                suffixIcon: _testResult != null
                    ? Icon(
                        _testResult! ? Icons.check_circle : Icons.error,
                        color: _testResult!
                            ? AppColors.safe
                            : AppColors.critical,
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Test connection
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed),
                label: Text(_isTesting
                    ? 'Đang kiểm tra...'
                    : AppStrings.testConnection),
              ),
            ),
            const SizedBox(height: 32),

            // Tên người được theo dõi
            Text(
              AppStrings.monitoringTarget,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetNameController,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Ông Nguyễn Văn A',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 32),

            // Mã ghép nối
            Text(
              AppStrings.pairingCode,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.enterPairingCode,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pairingCodeController,
              decoration: const InputDecoration(
                hintText: 'ABC-123-XYZ',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 48),

            // Save & Continue
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _canContinue ? _onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text(
                  'Hoàn tất cài đặt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canContinue =>
      _urlController.text.trim().isNotEmpty &&
      _targetNameController.text.trim().isNotEmpty;

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final wsService = ref.read(webSocketServiceProvider);
    final result =
        await wsService.testConnection(_urlController.text.trim());

    setState(() {
      _isTesting = false;
      _testResult = result;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result
              ? '✅ Kết nối thành công!'
              : '❌ Không thể kết nối. Kiểm tra lại địa chỉ.'),
          backgroundColor: result ? AppColors.safe : AppColors.critical,
        ),
      );
    }
  }

  Future<void> _onSave() async {
    final storage = ref.read(storageServiceProvider);

    await storage.setCloudUrl(_urlController.text.trim());
    await storage.setMonitorTargetName(_targetNameController.text.trim());
    if (_pairingCodeController.text.isNotEmpty) {
      await storage.setPairingCode(_pairingCodeController.text.trim());
    }

    // Cấu hình API service với cloud URL
    final apiService = ref.read(apiServiceProvider);
    apiService.configure(baseUrl: _urlController.text.trim());

    // Cấu hình WebSocket service
    final wsService = ref.read(webSocketServiceProvider);
    wsService.configure(serverUrl: _urlController.text.trim());
    wsService.connect();

    if (!mounted) return;
    context.go('/dashboard');
  }
}
