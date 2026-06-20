import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_report_model.dart';
import 'vitals_provider.dart';

/// Backend patient id to query the cloud (MongoDB) report archive for.
///
/// Every archived window is stored under the *collector's* patient id. The
/// Polar collector currently hardwires `polar_h10` (see backend
/// `src/api/pipeline.py`), so the only values that match archived data are that
/// id or the one carried by the live vitals stream. The onboarding device /
/// monitor codes must NOT be used here: `StorageService.setDeviceCode` and
/// `setMonitorTargetId` uppercase the input (e.g. `POLAR_H10`, `EC-001`), so
/// they never match the lowercase backend id and the report comes back empty.
final reportPatientIdProvider = Provider<String>((ref) {
  final live = ref.watch(vitalsProvider).currentVitals?.patientId;
  if (live != null && live.isNotEmpty) return live;
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
