import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_report_model.dart';
import 'vitals_provider.dart';

/// Effective patient id for reports: caregiver's monitored target, else the
/// live vitals patient, else the wearer's device code, else the default.
final reportPatientIdProvider = Provider<String>((ref) {
  final storage = ref.watch(storageServiceProvider);
  if (storage.isCaregiver && storage.monitorTargetId.isNotEmpty) {
    return storage.monitorTargetId;
  }
  final live = ref.watch(vitalsProvider).currentVitals?.patientId;
  if (live != null && live.isNotEmpty) return live;
  if (storage.isWearer && storage.deviceCode.isNotEmpty) {
    return storage.deviceCode;
  }
  return 'polar_h10';
});

/// Calendar days (newest first) that have report data in the cloud archive.
final availableReportDaysProvider =
    FutureProvider<List<AvailableDay>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final patientId = ref.watch(reportPatientIdProvider);
  final raw = await api.getAvailableReportDays(patientId: patientId);
  return raw
      .map((e) => AvailableDay.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Full statistical report for a given calendar date (YYYY-MM-DD).
final dailyReportProvider =
    FutureProvider.family<DailyReportModel, String>((ref, date) async {
  final api = ref.watch(apiServiceProvider);
  final patientId = ref.watch(reportPatientIdProvider);
  final json = await api.getDailyReport(date: date, patientId: patientId);
  return DailyReportModel.fromJson(json);
});
