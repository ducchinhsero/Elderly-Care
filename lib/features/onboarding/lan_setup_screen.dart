import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/services/lan_setup_service.dart';

class LanSetupScreen extends ConsumerStatefulWidget {
  const LanSetupScreen({super.key});

  @override
  ConsumerState<LanSetupScreen> createState() => _LanSetupScreenState();
}

class _LanSetupScreenState extends ConsumerState<LanSetupScreen> {
  final _hostController = TextEditingController();

  bool _isChecking = false;
  bool _isScanning = false;
  String? _message;
  bool _success = false;
  List<LanDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _hostController.text = ref.read(storageServiceProvider).gatewayIp;
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết nối Raspberry qua LAN'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InstructionCard(
            icon: Icons.settings_ethernet,
            title: '1. Cắm dây LAN',
            text:
                'Cắm Raspberry vào router hoặc switch bằng dây Ethernet. Chờ khoảng 30-60 giây để Raspberry nhận IP từ router.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '2. Nhập IP hoặc hostname',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'IP/hostname Raspberry',
                      helperText: 'Ví dụ: 10.10.56.149 hoặc elderlycare.local',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checkAndSave(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkAndSave,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Kiểm tra và lưu kết nối'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Backend hiện tại: ${storage.apiBaseUrl}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '3. Hoặc quét LAN',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'App sẽ quét các địa chỉ gần máy hiện tại trên port 8000. Nếu không tìm thấy, vẫn có thể nhập IP thủ công ở trên.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isScanning ? null : _scanLan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.manage_search_outlined),
                    label: const Text('Quét LAN tìm Raspberry'),
                  ),
                  if (_devices.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._devices.map(
                      (device) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lan_outlined),
                        title: Text(device.host),
                        subtitle: Text(device.baseUrl),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _hostController.text = device.host;
                          _checkAndSave();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _success ? AppColors.safeLight : AppColors.watchLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _success ? AppColors.safe : AppColors.watch,
                ),
              ),
              child: Text(
                _message!,
                style: TextStyle(
                  color: _success ? AppColors.safeDark : AppColors.watchDark,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _InstructionCard(
            icon: Icons.info_outline,
            title: 'Gợi ý ổn định',
            text:
                'Nên đặt DHCP reservation trên router để Raspberry luôn nhận cùng một IP. VNC/SSH cũng dùng chính IP LAN này.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndSave() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    final storage = ref.read(storageServiceProvider);
    final service = ref.read(lanSetupServiceProvider);
    try {
      final device = await service.checkHealth(
        _hostController.text,
        apiKey: storage.apiKey,
      );
      await storage.setGatewayIp(device.host);
      ref.read(apiServiceProvider).configure(
            baseUrl: storage.apiBaseUrl,
            apiKey: storage.apiKey,
            accessCode: storage.isCaregiver ? storage.pairingCode : null,
            deviceCode: storage.isWearer ? storage.deviceCode : null,
          );
      if (!mounted) return;
      setState(() {
        _success = true;
        _message =
            'Đã kết nối Raspberry tại ${device.baseUrl}. App sẽ dùng địa chỉ này cho dashboard và cảnh báo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _scanLan() async {
    setState(() {
      _isScanning = true;
      _message = null;
      _devices = [];
    });

    final storage = ref.read(storageServiceProvider);
    try {
      final devices = await ref.read(lanSetupServiceProvider).scanLan(
            apiKey: storage.apiKey,
          );
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _success = devices.isNotEmpty;
        _message = devices.isEmpty
            ? 'Chưa tìm thấy Raspberry trên LAN. Hãy nhập IP thủ công hoặc kiểm tra dây LAN/router.'
            : 'Đã tìm thấy ${devices.length} backend Raspberry. Chọn một địa chỉ để lưu.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }
}

class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
