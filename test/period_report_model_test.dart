import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/models/period_report_model.dart';

/// Verifies PeriodReportModel parses a representative /period-report payload
/// (shape produced by `daily_report.py:compute_period_report`).
void main() {
  Map<String, dynamic> sample() => {
        'patient_id': 'polar_h10',
        'period': 'week',
        'days': 7,
        'date_start': '2026-06-13',
        'date_end': '2026-06-19',
        'has_data': true,
        'total_windows': 9365,
        'reliable_windows': 8615,
        'day_count': 3,
        'good_signal_ratio': 0.9199,
        'signal_quality': {'good': 8000, 'fair': 615, 'poor': 750},
        'hr_stats': {'n': 8615, 'mean': 118.8, 'min': 60.0, 'max': 182.0, 'std': 20.0},
        'hr_bands': {'<60': 0, '60-99': 2000, '100-119': 3000, '120-149': 2500, '>=150': 1115},
        'days_detail': [
          {'day': '20260617', 'date': '2026-06-17', 'n': 200, 'mean': 100.0, 'min': 70.0, 'max': 150.0, 'pct_over100': 49.0, 'pct_over120': 30.0},
          {'day': '20260618', 'date': '2026-06-18', 'n': 4227, 'mean': 109.0, 'min': 60.0, 'max': 182.0, 'pct_over100': 53.0, 'pct_over120': 33.0},
          {'day': '20260619', 'date': '2026-06-19', 'n': 188, 'mean': 130.0, 'min': 90.0, 'max': 175.0, 'pct_over100': 98.0, 'pct_over120': 70.0},
        ],
        'rhythm': {'normal': 6000, 'other_rhythm': 1500, 'noise': 900, 'possible_afib': 215},
        'ectopy': {'normal': 5000, 'pvc': 1000, 'pac': 1100, 'mixed_ectopic': 30},
        'afib': {'mean': 0.046, 'max': 0.831, 'window_ratio': 0.0159, 'max_burden_percent': 71.43},
        'stress_stats': {'valid': 8000, 'stress': 3700, 'non_stress': 4300, 'pct_stress': 46.25},
        'total_events': 16901,
        'event_types': {
          'af_suspicion': 1781,
          'ectopy_suspicion': 3523,
          'critical_hr_immobile': 91,
          'fall_candidate': 4,
        },
        'event_severity': {'medium': 16000, 'high': 810, 'critical': 91},
        'critical_events': [
          {'date': '2026-06-18', 't': '21:21:46', 'type': 'fall_candidate', 'hr': null},
          {'date': '2026-06-18', 't': '22:30:00', 'type': 'critical_hr_immobile', 'hr': 165.0},
        ],
        'assessment': {
          'level': 'high',
          'score': 0.8,
          'summary': 'Multi-day risk/suspicion pattern detected: Repeated AFib-like pattern.',
          'findings': [
            {
              'type': 'long_term_afib_suspicion',
              'level': 'high',
              'title': 'Repeated AFib-like pattern',
              'reason': '...',
              'evidence': {'event_count': 1781, 'events_per_day': 593.67, 'max_af_burden_percent': 71.43},
            },
          ],
        },
      };

  test('PeriodReportModel.fromJson parses a week payload', () {
    final r = PeriodReportModel.fromJson(sample());

    expect(r.hasData, isTrue);
    expect(r.isWeek, isTrue);
    expect(r.dateStart, '2026-06-13');
    expect(r.dateEnd, '2026-06-19');
    expect(r.dayCount, 3);
    expect(r.hrStats!.mean, closeTo(118.8, 0.01));
    expect(r.daysDetail.length, 3);
    expect(r.daysDetail.last.mean, closeTo(130.0, 0.01));
    expect(r.hrBands['120-149'], 2500);
    expect(r.eventTypes['af_suspicion'], 1781);
    expect(r.criticalCount, 91);
    expect(r.ectopyTotal, 1000 + 1100 + 30);
    expect(r.afibMaxBurden, closeTo(71.43, 0.01));
    expect(r.criticalEvents.length, 2);
    expect(r.criticalEvents.first.hr, isNull);
    expect(r.assessment!.level, 'high');
    expect(r.assessment!.findings.single.type, 'long_term_afib_suspicion');
  });

  test('PeriodReportModel tolerates an empty (no-data) payload', () {
    final r = PeriodReportModel.fromJson({
      'patient_id': 'polar_h10',
      'period': 'month',
      'days': 30,
      'has_data': false,
      'total_windows': 0,
    });
    expect(r.hasData, isFalse);
    expect(r.dayCount, 0);
    expect(r.hrStats, isNull);
    expect(r.assessment, isNull);
    expect(r.daysDetail, isEmpty);
  });
}
