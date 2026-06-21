import 'package:elder_health_monitor/core/utils/alert_notification_policy.dart';
import 'package:elder_health_monitor/core/utils/health_display_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The supervisor (caregiver) only receives an immediate push when
  // [AlertNotificationPolicy.shouldPopup] returns true — that is the gate used
  // by both vitals_provider._notifyImmediateAlerts (device side) and
  // alerts_provider._notifyNewAlert (caregiver realtime side).
  group('Heart rate + movement context → immediate supervisor alert', () {
    // Heart rate that is abnormal *while the sensor reports the person is
    // immobile/inactive* is the contextual case that must reach the supervisor
    // right away. These are the `sustained_*_immobile` / `critical_hr_immobile`
    // event types emitted by the backend.
    const contextualTypes = [
      'sustained_tachycardia_immobile',
      'sustained_bradycardia_immobile',
      'critical_hr_immobile',
    ];

    for (final type in contextualTypes) {
      test('$type pops up (notifies supervisor) at ALERT/HIGH/CRITICAL', () {
        for (final level in ['ALERT', 'HIGH', 'CRITICAL']) {
          expect(
            AlertNotificationPolicy.shouldPopup(type: type, level: level),
            isTrue,
            reason: '$type @ $level must notify the supervisor immediately',
          );
        }
      });

      test('$type bypasses quiet hours when actionable', () {
        expect(
          AlertNotificationPolicy.bypassesQuietHours(
            type: type,
            level: 'ALERT',
          ),
          isTrue,
          reason: '$type is urgent enough to override quiet hours',
        );
      });

      test('$type stays silent at low (WATCH) level', () {
        expect(
          AlertNotificationPolicy.shouldPopup(type: type, level: 'WATCH'),
          isFalse,
          reason: 'a low-severity contextual HR reading should not alarm',
        );
      });
    }
  });

  group('Plain heart-rate (no movement context) → NOT immediate', () {
    // Single-window HR readings without the immobile/sustained context are
    // noisy, so they must NOT trigger an immediate supervisor push — even at
    // CRITICAL — to avoid alarm fatigue.
    const noisyTypes = [
      'tachycardia_at_rest',
      'bradycardia',
      'hr_context_high',
      'overall_alert',
      'critical_vitals',
    ];

    for (final type in noisyTypes) {
      test('$type does not pop up even at CRITICAL', () {
        for (final level in ['WATCH', 'ALERT', 'CRITICAL']) {
          expect(
            AlertNotificationPolicy.shouldPopup(type: type, level: level),
            isFalse,
            reason: '$type @ $level should not push immediately',
          );
        }
      });
    }
  });

  group('Fall detection → always notifies the supervisor', () {
    // The backend emits fall events as `fall`, `fall_candidate`, `strong_fall`.
    const fallTypes = ['fall', 'fall_candidate', 'strong_fall'];

    for (final type in fallTypes) {
      test('$type pops up at every severity level', () {
        for (final level in ['WATCH', 'ALERT', 'HIGH', 'CRITICAL']) {
          expect(
            AlertNotificationPolicy.shouldPopup(type: type, level: level),
            isTrue,
            reason: 'fall events must always reach the supervisor',
          );
        }
      });

      test('$type bypasses quiet hours', () {
        expect(
          AlertNotificationPolicy.bypassesQuietHours(
            type: type,
            level: 'WATCH',
          ),
          isTrue,
          reason: 'a fall at night must still wake the supervisor',
        );
      });
    }
  });

  group('HealthDisplayMapper labels', () {
    test('maps contextual HR alert types to plain Vietnamese labels', () {
      expect(
        HealthDisplayMapper.alertTitle('sustained_tachycardia_immobile'),
        'Nhịp tim cao khi đang ít vận động',
      );
      expect(
        HealthDisplayMapper.alertTitle('sustained_bradycardia_immobile'),
        'Nhịp tim thấp kéo dài',
      );
      expect(
        HealthDisplayMapper.alertTitle('critical_hr_immobile'),
        'Nhịp tim nguy hiểm khi người dùng đang bất động',
      );
    });

    test('maps fall event types to the fall label', () {
      for (final type in ['fall', 'fall_candidate', 'strong_fall']) {
        expect(HealthDisplayMapper.alertTitle(type), 'Nghi ngờ té ngã');
      }
    });
  });
}
