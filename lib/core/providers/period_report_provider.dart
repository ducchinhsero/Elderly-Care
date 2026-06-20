import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/period_report_model.dart';
import 'daily_report_provider.dart' show reportPatientIdProvider;
import 'vitals_provider.dart';

/// Weekly/monthly statistical report for a selected period ('week' | 'month').
final periodReportProvider =
    FutureProvider.family<PeriodReportModel, String>((ref, period) async {
  final api = ref.watch(apiServiceProvider);
  final patientId = ref.watch(reportPatientIdProvider);
  final json = await api.getPeriodReport(period: period, patientId: patientId);
  return PeriodReportModel.fromJson(json);
});
