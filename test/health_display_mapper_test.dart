import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/utils/health_display_mapper.dart';

void main() {
  group('HealthDisplayMapper', () {
    test('maps alert levels to user-friendly Vietnamese labels', () {
      expect(HealthDisplayMapper.levelLabel('SAFE'), 'Ổn định');
      expect(HealthDisplayMapper.levelLabel('WATCH'), 'Cần theo dõi');
      expect(HealthDisplayMapper.levelLabel('ALERT'), 'Cần kiểm tra');
      expect(HealthDisplayMapper.levelLabel('CRITICAL'), 'Cần hỗ trợ ngay');
    });

    test('maps backend alert types to plain-language titles and actions', () {
      expect(
          HealthDisplayMapper.alertTitle('fall_candidate'), 'Nghi ngờ té ngã');
      expect(
        HealthDisplayMapper.alertAction('fall_candidate', 'CRITICAL'),
        'Kiểm tra người dùng ngay.',
      );

      expect(
        HealthDisplayMapper.alertTitle('afib_suspicion'),
        'Dấu hiệu nhịp tim không đều',
      );
      expect(HealthDisplayMapper.alertTitle('rhythm_alert'),
          'Dấu hiệu nhịp tim không đều');
      expect(HealthDisplayMapper.alertTitle('ectopy_suspicion'),
          'Có nhịp đến sớm');
      expect(
        HealthDisplayMapper.alertTitle('tachycardia_at_rest'),
        'Nhịp tim nhanh hơn bình thường',
      );
      expect(
        HealthDisplayMapper.alertTitle('bradycardia'),
        'Nhịp tim chậm hơn bình thường',
      );
      expect(HealthDisplayMapper.alertTitle('poor_signal'),
          'Tín hiệu đo chưa tốt');
    });

    test('lists backend APIs surfaced in technical data section', () {
      expect(HealthDisplayMapper.apiEndpoints, contains('GET /health'));
      expect(HealthDisplayMapper.apiEndpoints, contains('GET /latest-result'));
      expect(HealthDisplayMapper.apiEndpoints, contains('GET /history'));
      expect(HealthDisplayMapper.apiEndpoints, contains('GET /events'));
      expect(HealthDisplayMapper.apiEndpoints, contains('GET /health-report'));
      expect(
          HealthDisplayMapper.apiEndpoints, contains('GET /api/user/{userId}'));
      expect(
        HealthDisplayMapper.apiEndpoints,
        contains('POST /guided-baseline/segment/complete'),
      );
    });
  });
}
