import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/models/health_report_model.dart';
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
        'risk': {'level': 'medium', 'score': 0.4, 'reason': 'Repeated rhythm event.'},
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
    expect(vitals.ectopyLabel, 'pvc');
    expect(vitals.clinicalAlerts, isNotEmpty);
  });

  test('HealthReportModel parses three time layers', () {
    final report = HealthReportModel.fromJson({
      'patient_id': 'polar_h10',
      'overall': {'level': 'high', 'summary': 'Highest level.'},
      'layers': {
        'realtime': {
          'title': 'Realtime',
          'window': {'mode': 'latest_window', 'minutes': 5},
          'overall': {'level': 'medium', 'score': 0.5, 'summary': 'Current alert.'},
          'findings': [],
        },
        'daily': {
          'period': {'mode': 'rolling_24h', 'hours': 24},
          'overall': {'level': 'high', 'score': 0.8, 'summary': 'Daily pattern.'},
          'findings': [
            {'type': 'afib_suspicion', 'level': 'high', 'title': 'Possible AFib'}
          ],
        },
        'long_term': {
          'window': {'mode': 'rolling_days', 'days': 7, 'prediction_count': 120},
          'overall': {'level': 'low', 'score': 0.2, 'summary': 'Stable.'},
          'findings': [],
        },
      },
    });

    expect(report.overallLevel, 'high');
    expect(report.realtime.windowLabel, 'Cửa sổ mới nhất');
    expect(report.daily.findings.first.type, 'afib_suspicion');
    expect(report.longTerm.windowLabel, contains('7 ngày'));
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
}
