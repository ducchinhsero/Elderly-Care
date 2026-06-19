import 'package:elder_health_monitor/core/utils/alert_notification_policy.dart';
import 'package:elder_health_monitor/core/utils/health_display_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlertNotificationPolicy', () {
    test('does not popup for single-window heart-rate alerts', () {
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'tachycardia_at_rest',
          level: 'ALERT',
        ),
        isFalse,
      );
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'bradycardia',
          level: 'CRITICAL',
        ),
        isFalse,
      );
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'overall_alert',
          level: 'ALERT',
        ),
        isFalse,
      );
    });

    test('popups for sustained immobile heart-rate and fall alerts', () {
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'sustained_tachycardia_immobile',
          level: 'ALERT',
        ),
        isTrue,
      );
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'sustained_bradycardia_immobile',
          level: 'ALERT',
        ),
        isTrue,
      );
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'critical_hr_immobile',
          level: 'CRITICAL',
        ),
        isTrue,
      );
      expect(
        AlertNotificationPolicy.shouldPopup(
          type: 'fall_candidate',
          level: 'CRITICAL',
        ),
        isTrue,
      );
    });
  });

  group('HealthDisplayMapper sustained alerts', () {
    test('maps sustained alert types to plain Vietnamese labels', () {
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
  });
}
