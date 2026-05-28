import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import 'widgets/comorbidity_selector.dart';
import 'widgets/medication_selector.dart';
import 'widgets/threshold_adjustment_widget.dart';
import 'widgets/calibration_widget.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _physicianNameCtrl;
  late TextEditingController _physicianPhoneCtrl;
  late TextEditingController _medicalNotesCtrl;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyPhoneCtrl;
  late TextEditingController _hrBaselineCtrl;
  late TextEditingController _rmssdBaselineCtrl;

  DateTime? _dob;
  String _gender = 'male';
  List<String> _comorbidities = [];
  List<String> _medications = [];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProvider).profile;

    _nameCtrl = TextEditingController(text: profile?.fullName ?? '');
    _weightCtrl =
        TextEditingController(text: profile?.weightKg?.toString() ?? '');
    _heightCtrl =
        TextEditingController(text: profile?.heightCm?.toString() ?? '');
    _physicianNameCtrl =
        TextEditingController(text: profile?.primaryPhysician ?? '');
    _physicianPhoneCtrl =
        TextEditingController(text: profile?.physicianPhone ?? '');
    _medicalNotesCtrl =
        TextEditingController(text: profile?.medicalNotes ?? '');
    _emergencyNameCtrl =
        TextEditingController(text: profile?.emergencyContactName ?? '');
    _emergencyPhoneCtrl =
        TextEditingController(text: profile?.emergencyContactPhone ?? '');
    _hrBaselineCtrl = TextEditingController(
        text: profile?.restingHrBaseline?.toString() ?? '');
    _rmssdBaselineCtrl =
        TextEditingController(text: profile?.rmssdBaseline?.toString() ?? '');

    _dob = profile?.dateOfBirth;
    _gender = profile?.gender ?? 'male';
    _comorbidities = List.from(profile?.comorbidities ?? []);
    _medications = List.from(profile?.medications ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _physicianNameCtrl.dispose();
    _physicianPhoneCtrl.dispose();
    _medicalNotesCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _hrBaselineCtrl.dispose();
    _rmssdBaselineCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dob ?? DateTime.now().subtract(const Duration(days: 65 * 365)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() => _dob = picked);
    }
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final currentProfile = ref.read(userProvider).profile;
      if (currentProfile == null) return;

      final updated = currentProfile.copyWith(
        fullName: _nameCtrl.text,
        dateOfBirth: _dob,
        gender: _gender,
        weightKg: double.tryParse(_weightCtrl.text),
        heightCm: double.tryParse(_heightCtrl.text),
        primaryPhysician: _physicianNameCtrl.text,
        physicianPhone: _physicianPhoneCtrl.text,
        medicalNotes: _medicalNotesCtrl.text,
        emergencyContactName: _emergencyNameCtrl.text,
        emergencyContactPhone: _emergencyPhoneCtrl.text,
        restingHrBaseline: int.tryParse(_hrBaselineCtrl.text),
        rmssdBaseline: double.tryParse(_rmssdBaselineCtrl.text),
        comorbidities: _comorbidities,
        medications: _medications,
      );

      ref.read(userProvider.notifier).updateProfile(updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Hồ sơ đã được lưu! Ngưỡng cảnh báo đã tự động cập nhật.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final profile = userState.profile;

    if (userState.isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ sức khỏe')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Thông tin cơ bản
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person,
                                size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Họ và tên'),
                              validator: (val) =>
                                  val!.isEmpty ? 'Vui lòng nhập tên' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                    labelText: 'Ngày sinh',
                                    suffixIcon: Icon(Icons.calendar_today)),
                                child: Text(_dob != null
                                    ? DateFormat('dd/MM/yyyy').format(_dob!)
                                    : 'Chọn ngày'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'male', label: Text('Nam')),
                                ButtonSegment(
                                    value: 'female', label: Text('Nữ')),
                              ],
                              selected: {_gender},
                              onSelectionChanged: (set) =>
                                  setState(() => _gender = set.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: _weightCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Cân nặng (kg)'),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextFormField(
                                  controller: _heightCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Chiều cao (cm)'),
                                  keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 2: Bệnh nền
              ComorbiditySelectorWidget(
                selected: _comorbidities,
                onChanged: (list) => setState(() => _comorbidities = list),
              ),
              const SizedBox(height: 16),

              // Section 3: Thuốc
              MedicationSelectorWidget(
                selected: _medications,
                onChanged: (list) => setState(() => _medications = list),
              ),
              const SizedBox(height: 16),

              // Threshold Adjustment Widget (hiện nếu có profile)
              if (profile != null) ...[
                ThresholdAdjustmentWidget(profile: profile),
                const SizedBox(height: 16),
              ],

              // Section 4: Bác sĩ điều trị
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bác sĩ điều trị',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _physicianNameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Tên bác sĩ',
                              prefixIcon:
                                  Icon(Icons.medical_services_outlined))),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _physicianPhoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              prefixIcon: Icon(Icons.phone_outlined)),
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _medicalNotesCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Ghi chú (VD: HR mục tiêu 55-70 BPM)'),
                          maxLines: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 5: Mức bình thường riêng
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mức bình thường của riêng bạn',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                          'Để trống nếu không biết. App sẽ tự học từ dữ liệu đo tốt trong vài ngày.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textHint)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: _hrBaselineCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Nhịp tim khi nghỉ (BPM)'),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextFormField(
                                  controller: _rmssdBaselineCtrl,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Mức phục hồi thường thấy (ms)'),
                                  keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Calibration (nếu có Profile thực tế)
              if (profile != null) ...[
                CalibrationWidget(
                  isCalibrated: profile.isCalibrated,
                  lastCalibratedAt: profile.lastCalibratedAt,
                  needsRecalibration: profile.needsRecalibration,
                  isCalibrating: userState.isCalibrating,
                  secondsRemaining: userState.calibrationSecondsRemaining,
                  onCalibrate: () => _showCalibrationDialog(context, ref),
                ),
                const SizedBox(height: 16),
              ],

              // Section 6: Liên hệ khẩn cấp
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emergency,
                              color: AppColors.critical, size: 20),
                          const SizedBox(width: 8),
                          Text(AppStrings.emergencyContact,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _emergencyNameCtrl,
                          decoration: const InputDecoration(
                              labelText: AppStrings.emergencyName,
                              prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _emergencyPhoneCtrl,
                          decoration: const InputDecoration(
                              labelText: AppStrings.emergencyPhone,
                              prefixIcon: Icon(Icons.phone_outlined)),
                          keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _saveProfile,
                  child: const Text('Lưu hồ sơ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Thiết lập mức bình thường của bạn'),
        content: const Text(
            'App sẽ học mức nhịp tim thường thấy của riêng bạn. Sau đó, cảnh báo sẽ sát với cơ thể bạn hơn và ít báo nhầm hơn.\n\n'
            'Trong thời gian này, hãy:\n'
            '✓ Ngồi hoặc nằm nghỉ ngơi\n'
            '✓ Không vận động\n'
            '✓ Giữ Polar H10 đeo vừa vặn\n'
            '✗ Không uống cafe hoặc trà đặc trước 1 giờ'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(userProvider.notifier).startCalibration();
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }
}
