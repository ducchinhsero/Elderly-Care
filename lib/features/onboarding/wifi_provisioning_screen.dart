import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/wifi_provisioning_service.dart';

class WifiProvisioningScreen extends ConsumerStatefulWidget {
  const WifiProvisioningScreen({super.key});

  @override
  ConsumerState<WifiProvisioningScreen> createState() =>
      _WifiProvisioningScreenState();
}

class _WifiProvisioningScreenState
    extends ConsumerState<WifiProvisioningScreen> {
  final _manualSsidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoadingStatus = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  WifiProvisioningStatus? _status;
  List<WifiNetwork> _networks = [];
  String? _selectedSsid;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _manualSsidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiet lap Wi-Fi Raspberry'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InstructionCard(
            icon: Icons.wifi_tethering,
            title: '1. Ket noi Wi-Fi setup',
            text:
                'Mo cai dat Wi-Fi tren dien thoai va ket noi vao mang ElderlyCare-Setup-XXXX. Sau do quay lai man hinh nay va bam Kiem tra portal.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Portal setup',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        _status == null
                            ? Icons.radio_button_unchecked
                            : Icons.check_circle,
                        color: _status == null
                            ? AppColors.textHint
                            : AppColors.safe,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status == null
                        ? 'Chua kiem tra ket noi den http://10.42.0.1'
                        : 'Trang thai: ${_status!.mode}'
                            '${_status!.setupSsid != null ? ' | ${_status!.setupSsid}' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (_status?.lastError != null &&
                      _status!.lastError!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _status!.lastError!,
                      style: const TextStyle(color: AppColors.critical),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingStatus ? null : _loadStatus,
                          icon: _isLoadingStatus
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.router_outlined),
                          label: const Text('Kiem tra portal'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Mo portal web du phong',
                        onPressed: _openPortalInBrowser,
                        icon: const Icon(Icons.open_in_browser),
                      ),
                    ],
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
                    '2. Chon Wi-Fi nha',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isScanning ? null : _scanWifi,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_outlined),
                    label: const Text('Quet Wi-Fi xung quanh'),
                  ),
                  if (_networks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSsid,
                      items: _networks
                          .map(
                            (network) => DropdownMenuItem(
                              value: network.ssid,
                              child: Text(
                                '${network.ssid}'
                                '${network.signal != null ? ' (${network.signal}%)' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selectedSsid = value;
                        _manualSsidController.clear();
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Wi-Fi tim thay',
                        prefixIcon: Icon(Icons.wifi),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualSsidController,
                    decoration: const InputDecoration(
                      labelText: 'Hoac nhap ten Wi-Fi thu cong',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    onChanged: (_) => setState(() => _selectedSsid = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mat khau Wi-Fi',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _connectWifi,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Gui cau hinh Wi-Fi cho Raspberry'),
                  ),
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
            icon: Icons.home_outlined,
            title: '3. Quay lai Wi-Fi nha',
            text:
                'Neu mat mang ElderlyCare-Setup sau khi gui cau hinh, do la tin hieu tot: Raspberry dang chuyen sang Wi-Fi nha. Hay ket noi dien thoai lai Wi-Fi nha, sau do vao Cai dat app va kiem tra backend http://IP:8000/health.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Quay lai'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoadingStatus = true;
      _message = null;
    });
    try {
      final status =
          await ref.read(wifiProvisioningServiceProvider).getStatus();
      setState(() {
        _status = status;
        _success = true;
        _message = 'Da ket noi duoc portal setup. Co the quet Wi-Fi.';
      });
    } catch (e) {
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _scanWifi() async {
    setState(() {
      _isScanning = true;
      _message = null;
    });
    try {
      final networks =
          await ref.read(wifiProvisioningServiceProvider).scanNetworks();
      setState(() {
        _networks = networks;
        _selectedSsid = networks.isNotEmpty ? networks.first.ssid : null;
        _success = networks.isNotEmpty;
        _message = networks.isEmpty
            ? 'Khong tim thay Wi-Fi nao. Co the thu lai sau vai giay.'
            : 'Da tim thay ${networks.length} mang Wi-Fi.';
      });
    } catch (e) {
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectWifi() async {
    final ssid = _manualSsidController.text.trim().isNotEmpty
        ? _manualSsidController.text.trim()
        : (_selectedSsid ?? '');
    setState(() {
      _isConnecting = true;
      _message = null;
    });
    try {
      await ref.read(wifiProvisioningServiceProvider).connectWifi(
            ssid: ssid,
            password: _passwordController.text,
          );
      setState(() {
        _success = true;
        _message =
            'Da gui cau hinh Wi-Fi. Raspberry se tat Wi-Fi setup neu mat khau dung. Hay chuyen dien thoai ve Wi-Fi nha va kiem tra backend trong app.';
      });
    } catch (e) {
      setState(() {
        _success = false;
        _message = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _openPortalInBrowser() async {
    final uri = Uri.parse(WifiProvisioningService.defaultPortalBaseUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
