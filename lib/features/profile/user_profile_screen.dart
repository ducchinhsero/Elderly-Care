import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/user_provider.dart';
import 'widgets/comorbidity_selector.dart';
import 'widgets/calibration_widget.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider);
    final profile = userState.profile;

    if (userState.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + Name + Age
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        profile?.name.isNotEmpty == true ? profile!.name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(profile?.name ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    Text('${profile?.age ?? 0} tuổi', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Comorbidities
            ComorbiditySelectorWidget(
              selected: profile?.comorbidities ?? [],
              onChanged: (list) => ref.read(userProvider.notifier).updateComorbidities(list),
            ),
            const SizedBox(height: 16),

            // Medications
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.medications, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(hintText: 'Nhập thuốc đang dùng...'),
                      controller: TextEditingController(text: profile?.medications ?? ''),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Calibration
            CalibrationWidget(
              calibration: profile?.calibration,
              isCalibrating: userState.isCalibrating,
              secondsRemaining: userState.calibrationSecondsRemaining,
              onCalibrate: () => _showCalibrationDialog(context, ref),
            ),
            const SizedBox(height: 16),

            // Emergency Contact
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emergency, color: AppColors.critical, size: 20),
                        const SizedBox(width: 8),
                        Text(AppStrings.emergencyContact, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: AppStrings.emergencyName, prefixIcon: Icon(Icons.person_outline)),
                      controller: TextEditingController(text: profile?.emergencyContact?.name ?? ''),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(labelText: AppStrings.emergencyPhone, prefixIcon: Icon(Icons.phone_outlined)),
                      controller: TextEditingController(text: profile?.emergencyContact?.phone ?? ''),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.calibrateBaseline),
        content: const Text(AppStrings.calibrateExplain),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(userProvider.notifier).startCalibration();
            },
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
  }
}
