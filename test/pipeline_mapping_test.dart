import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/models/health_report_model.dart';
import 'package:elder_health_monitor/core/models/guided_baseline_model.dart';
import 'package:elder_health_monitor/core/models/vitals_model.dart';
import 'package:elder_health_monitor/core/models/alert_model.dart';

void main() {
  test('VitalsModel parses ECG pipeline latest_result payload', () {
    final vitals = VitalsModel.fromJson({
      'latest_result': {
        'patient_id': 'polar_h10',
        'timestamp': '2026-05-22T10:30:00+07:00',
        'window_count': 6,
        'heart_rate_bpm': 82.5,
        'emotion': {'label': 'stress', 'confidence': 0.81},
        'rhythm': {
          'label': 'possible_afib',
          'confidence': 0.72,
          'possible_afib_probability': 0.42,
        },
        'rhythm_alert': {
          'level': 'medium',
          'message': 'Possible AFib pattern detected.',
        },
        'ectopy': {
          'label': 'pvc',
          'pvc_probability': 0.66,
          'pac_probability': 0.12,
        },
        'anomaly': {'label': 'normal', 'value': 0},
        'signal_quality': {'label': 'good', 'score': 0.95},
        'hrv': {'rmssd_ms': 27.4},
        'risk': {
          'level': 'medium',
          'score': 0.4,
          'reason': 'Repeated rhythm event.'
        },
        'sensor_context': {
          'activity_state': 'REST',
          'fall': {'fall_candidate': false},
        },
        'alert_level': 'medium',
        'message': 'Monitor rhythm.',
      }
    });

    expect(vitals.patientId, 'polar_h10');
    expect(vitals.hrBpm, 82.5);
    expect(vitals.alertLevel, 'WATCH');
    expect(vitals.emotion, 'stressed');
    expect(vitals.rhythmLabel, 'possible_afib');
    expect(vitals.afibProbability, 0.42);
    expect(vitals.rmssdMs, 27.4);
    expect(vitals.ectopyLabel, 'pvc');
    expect(vitals.clinicalAlerts, isNotEmpty);
  });

  test('VitalsModel maps fall candidate to urgent alert', () {
    final vitals = VitalsModel.fromJson({
      'patient_id': 'edge-01',
      'heart_rate_bpm': 91.0,
      'sensor_context': {
        'fall': {'fall_candidate': true},
      },
      'alert_level': 'normal',
    });

    expect(vitals.alertLevel, 'ALERT');
    expect(vitals.clinicalAlerts.first.type, 'fall_candidate');
  });

  test('HealthReportModel parses three time layers', () {
    final report = HealthReportModel.fromJson({
      'patient_id': 'polar_h10',
      'overall': {'level': 'high', 'summary': 'Highest level.'},
      'layers': {
        'realtime': {
          'title': 'Realtime',
          'window': {'mode': 'latest_window', 'minutes': 5},
          'overall': {
            'level': 'medium',
            'score': 0.5,
            'summary': 'Current alert.'
          },
          'findings': [],
        },
        'daily': {
          'period': {'mode': 'rolling_24h', 'hours': 24},
          'overall': {
            'level': 'high',
            'score': 0.8,
            'summary': 'Daily pattern.'
          },
          'findings': [
            {
              'type': 'afib_suspicion',
              'level': 'high',
              'title': 'Possible AFib'
            }
          ],
        },
        'long_term': {
          'window': {
            'mode': 'rolling_days',
            'days': 7,
            'prediction_count': 120
          },
          'overall': {'level': 'low', 'score': 0.2, 'summary': 'Stable.'},
          'findings': [],
        },
      },
      'personal_baseline': {
        'calibrated': true,
        'calibration': {
          'status': 'warming_up',
          'day_count': 3,
          'target_days': 7,
          'progress_ratio': 0.43,
          'data_quality_ok': true,
        },
        'comparisons': {
          'mean_hr_delta_bpm': 4.2,
          'resting_hr_delta_bpm': 2.1,
          'af_suspicion_ratio_delta': 0.04,
          'ectopy_ratio_delta': 0.01,
          'abnormal_ratio_delta': 0.0,
        },
      },
    });

    expect(report.overallLevel, 'high');
    expect(report.userLevelText, 'Cần kiểm tra');
    expect(report.realtime.windowLabel, 'Lần đo gần nhất');
    expect(report.daily.findings.first.type, 'afib_suspicion');
    expect(report.daily.findings.first.displayTitle,
        'Dấu hiệu nhịp tim không đều');
    expect(report.longTerm.windowLabel, contains('7 ngày'));
    expect(report.personalBaseline.status, 'warming_up');
    expect(report.personalBaseline.comparisonRows, isNotEmpty);
  });

  test('HealthReportModel tolerates missing findings and baseline', () {
    final report = HealthReportModel.fromJson({
      'overall': {'level': 'unknown'},
      'layers': {
        'daily': {
          'period': {'mode': 'rolling_24h', 'hours': 24},
          'overall': {'level': 'low'},
        },
      },
    });

    expect(report.daily.findings, isEmpty);
    expect(report.personalBaseline.calibrated, isFalse);
    expect(healthLevelText('medium'), 'Cần theo dõi');
  });

  test('AlertModel parses event timeline payload', () {
    final alert = AlertModel.fromJson({
      'event_id': 'event-1',
      'timestamp': '2026-05-22T10:30:00+07:00',
      'event_type': 'tachycardia',
      'severity': 'medium',
      'message': 'Heart rate is high while resting.',
      'heart_rate_bpm': 112.0,
      'activity_state': 'REST',
    });

    expect(alert.id, 'event-1');
    expect(alert.type, 'tachycardia');
    expect(alert.level, 'WATCH');
    expect(alert.hrBpm, 112.0);
    expect(alert.activity, 'REST');
  });

  test('GuidedBaselineStatus parses guided session payload', () {
    final status = GuidedBaselineStatus.fromJson({
      'patient_id': 'polar_h10',
      'status': 'warming_up',
      'day_count': 2,
      'target_days': 7,
      'progress_ratio': 0.2857,
      'segment_plan': [
        {
          'segment_type': 'REST',
          'expected_activity': 'REST',
          'duration_seconds': 300,
          'instruction': 'Sit quietly.'
        }
      ],
      'latest_session': {
        'session_id': 'session-1',
        'status': 'in_progress',
        'day_index': 3,
        'target_days': 7,
        'segments': [
          {
            'segment_type': 'REST',
            'status': 'completed',
            'duration_seconds': 300,
            'valid_window_count': 4,
            'rejected_window_count': 1,
            'rejection_reasons': []
          }
        ],
      },
    });

    expect(status.patientId, 'polar_h10');
    expect(status.segmentPlan.first.title, 'Nghi yen');
    expect(status.latestSession?.sessionId, 'session-1');
    expect(status.latestSession?.segments.first.validWindowCount, 4);
  });
}
