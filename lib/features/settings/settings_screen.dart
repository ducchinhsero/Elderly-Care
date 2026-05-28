import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/vitals_provider.dart';
import '../../core/utils/health_display_mapper.dart';
import 'widgets/alert_threshold_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '1883');
  final _codeController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _autoReconnect = true;
  bool _notifCritical = true;
  bool _notifAlert = true;
  bool _notifWatch = false;
  bool _quietHours = true;
  bool _autoThresholds = true;
  bool _darkMode = false;
  bool _isTesting = false;
  bool? _testResult;
  bool _isCheckingTechnical = false;
  bool? _technicalHealthResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = ref.read(storageServiceProvider);
    _ipController.text = storage.gatewayIp;
    _portController.text = storage.mqttPort.toString();
    _codeController.text =
        storage.isCaregiver ? storage.pairingCode : storage.deviceCode;
    _emergencyPhoneController.text = storage.emergencyPhone;
    _autoReconnect = storage.autoReconnect;
    _notifCritical = storage.notifCritical;
    _notifAlert = storage.notifAlert;
    _notifWatch = storage.notifWatch;
    _quietHours = storage.quietHoursEnabled;
    _autoThresholds = storage.autoThresholds;
    _darkMode = storage.isDarkMode;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _codeController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final isCaregiver = storage.isCaregiver;
    final roleName =
        isCaregiver ? AppStrings.roleCaregiver : AppStrings.roleWearer;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Vai trò hiện tại ──
          Card(
            child: ListTile(
              leading: Icon(
                isCaregiver ? Icons.visibility : Icons.watch,
                color: AppColors.primary,
              ),
              title: Text('Vai trò: $roleName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                isCaregiver ? AppStrings.remoteMode : AppStrings.localMode,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: TextButton(
                onPressed: () => _changeRole(context),
                child: const Text(AppStrings.changeRole,
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Kết nối ──
          _SectionHeader(title: AppStrings.connection, icon: Icons.wifi),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Caregiver: access code. Cloud endpoint is internal build config.
                  if (isCaregiver) ...[
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.accessCode,
                        hintText: AppStrings.accessCodeHint,
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      onChanged: (v) =>
                          ref.read(storageServiceProvider).setPairingCode(v),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: const Text('Cloud hệ thống'),
                      subtitle: Text(
                        'Endpoint cloud được cấu hình trong bản build. Raspberry gửi dữ liệu đã xử lý lên cloud để app đồng bộ từ xa.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  // Wearer: Local IP + MQTT
                  if (!isCaregiver) ...[
                    TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.deviceCode,
                        prefixIcon: Icon(Icons.memory),
                      ),
                      onChanged: (v) =>
                          ref.read(storageServiceProvider).setDeviceCode(v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                            labelText: AppStrings.gatewayIp,
                            prefixIcon: Icon(Icons.router))),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _portController,
                        decoration: const InputDecoration(
                            labelText: AppStrings.mqttPort,
                            prefixIcon: Icon(Icons.settings_ethernet)),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.speed),
                          label: Text(_isTesting
                              ? 'Đang kiểm tra...'
                              : AppStrings.testConnection),
                        ),
                      ),
                      if (_testResult != null) ...[
                        const SizedBox(width: 8),
                        Icon(_testResult! ? Icons.check_circle : Icons.error,
                            color: _testResult!
                                ? AppColors.safe
                                : AppColors.critical),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                      title: const Text(AppStrings.autoReconnect),
                      value: _autoReconnect,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        setState(() => _autoReconnect = v);
                        ref.read(storageServiceProvider).setAutoReconnect(v);
                      }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildTechnicalDataSection(storage),
          const SizedBox(height: 16),

          // ── Thông báo ──
          _SectionHeader(
              title: AppStrings.notifications,
              icon: Icons.notifications_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                    title: const Text(AppStrings.notifCritical),
                    subtitle: const Text('Heads-up + âm thanh + rung',
                        style: TextStyle(fontSize: 12)),
                    value: _notifCritical,
                    onChanged: (v) {
                      setState(() => _notifCritical = v);
                      ref.read(storageServiceProvider).setNotifCritical(v);
                    }),
                const Divider(height: 1),
                SwitchListTile(
                    title: const Text(AppStrings.notifAlert),
                    subtitle: const Text('Thông báo thường',
                        style: TextStyle(fontSize: 12)),
                    value: _notifAlert,
                    onChanged: (v) {
                      setState(() => _notifAlert = v);
                      ref.read(storageServiceProvider).setNotifAlert(v);
                    }),
                const Divider(height: 1),
                SwitchListTile(
                    title: const Text(AppStrings.notifWatch),
                    subtitle: const Text('Badge only, im lặng',
                        style: TextStyle(fontSize: 12)),
                    value: _notifWatch,
                    onChanged: (v) {
                      setState(() => _notifWatch = v);
                      ref.read(storageServiceProvider).setNotifWatch(v);
                    }),
                const Divider(height: 1),
                SwitchListTile(
                    title: const Text(AppStrings.quietHours),
                    subtitle: const Text(AppStrings.quietHoursDesc,
                        style: TextStyle(fontSize: 12)),
                    value: _quietHours,
                    onChanged: (v) {
                      setState(() => _quietHours = v);
                      ref.read(storageServiceProvider).setQuietHoursEnabled(v);
                    }),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                      controller: _emergencyPhoneController,
                      decoration: const InputDecoration(
                          labelText: AppStrings.emergencyCall,
                          prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      onChanged: (v) => ref
                          .read(storageServiceProvider)
                          .setEmergencyPhone(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Ngưỡng ──
          _SectionHeader(title: AppStrings.displayThresholds, icon: Icons.tune),
          AlertThresholdWidget(
            autoThresholds: _autoThresholds,
            onAutoChanged: (v) {
              setState(() => _autoThresholds = v);
              ref.read(storageServiceProvider).setAutoThresholds(v);
            },
          ),
          const SizedBox(height: 16),

          // ── Giao diện ──
          _SectionHeader(
              title: AppStrings.appearance, icon: Icons.palette_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                    title: const Text(AppStrings.darkMode),
                    secondary: const Icon(Icons.dark_mode),
                    value: _darkMode,
                    onChanged: (v) {
                      setState(() => _darkMode = v);
                      ref.read(storageServiceProvider).setDarkMode(v);
                    }),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text(AppStrings.language),
                    trailing: Text(AppStrings.vietnamese,
                        style: TextStyle(color: AppColors.textSecondary))),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTechnicalDataSection(dynamic storage) {
    final headers = storage.isCaregiver
        ? HealthDisplayMapper.caregiverHeaders
        : HealthDisplayMapper.wearerHeaders;
    final roleText = storage.isCaregiver
        ? 'Người giám sát dùng cloud'
        : 'Người đeo dùng gateway nội bộ';

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.data_object, color: AppColors.primary),
        title: const Text(
          'Dữ liệu kỹ thuật',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'API, backend và mapping cảnh báo',
          style: TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _TechnicalRow(label: 'Backend hiện tại', value: storage.apiBaseUrl),
          _TechnicalRow(label: 'Cách chọn URL', value: roleText),
          _TechnicalRow(label: 'Header gửi kèm', value: headers.join(', ')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isCheckingTechnical ? null : _checkTechnicalHealth,
                  icon: _isCheckingTechnical
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Kiểm tra /health'),
                ),
              ),
              if (_technicalHealthResult != null) ...[
                const SizedBox(width: 8),
                Icon(
                  _technicalHealthResult!
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _technicalHealthResult!
                      ? AppColors.safe
                      : AppColors.critical,
                ),
              ],
            ],
          ),
          const Divider(height: 24),
          _TechnicalList(
            title: 'API app đang gọi',
            items: HealthDisplayMapper.apiEndpoints,
          ),
          const Divider(height: 24),
          _MappingList(items: HealthDisplayMapper.alertMappings),
        ],
      ),
    );
  }

  Future<void> _checkTechnicalHealth() async {
    setState(() {
      _isCheckingTechnical = true;
      _technicalHealthResult = null;
    });
    final storage = ref.read(storageServiceProvider);
    final api = ref.read(apiServiceProvider)
      ..configure(
        baseUrl: storage.apiBaseUrl,
        accessCode: storage.isCaregiver ? storage.pairingCode : null,
        deviceCode: storage.isWearer ? storage.deviceCode : null,
      );
    final result = await api.healthCheck();
    if (!mounted) return;
    setState(() {
      _isCheckingTechnical = false;
      _technicalHealthResult = result;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final storage = ref.read(storageServiceProvider);

    bool result;
    if (storage.isCaregiver) {
      final apiService = ref.read(apiServiceProvider);
      apiService.configure(
        baseUrl: storage.apiBaseUrl,
        accessCode: storage.pairingCode,
      );
      result = await apiService.healthCheck();
    } else {
      // Test MQTT connection
      final mqttService = ref.read(mqttServiceProvider);
      result = await mqttService.testConnection(
          _ipController.text, int.tryParse(_portController.text) ?? 1883);
    }
    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  Future<void> _changeRole(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.changeRole),
        content: const Text(
            'Bạn sẽ quay lại màn hình chọn vai trò. Cài đặt hiện tại sẽ được giữ lại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(AppStrings.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(AppStrings.confirm)),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storage = ref.read(storageServiceProvider);
      await storage.setOnboardingCompleted(false);
      if (context.mounted) context.go('/role-selection');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _TechnicalRow extends StatelessWidget {
  final String label;
  final String value;

  const _TechnicalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '--' : value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalList extends StatelessWidget {
  final String title;
  final List<String> items;

  const _TechnicalList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: AppColors.textHint)),
                Expanded(
                  child: SelectableText(
                    item,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MappingList extends StatelessWidget {
  final List<AlertMappingInfo> items;

  const _MappingList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mapping cảnh báo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  item.backendType,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.userTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.userAction,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
