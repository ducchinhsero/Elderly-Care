import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/constants/mqtt_topics.dart';

void main() {
  test('MQTT topics match Edge AI backend wildcard topics', () {
    expect(MqttTopics.vitals, 'elderly_care/+/vitals/live');
    expect(MqttTopics.alert, 'elderly_care/+/alert');
    expect(MqttTopics.status, 'elderly_care/service/status');
  });

  test('MQTT topic routing accepts patient-specific backend topics', () {
    expect(MqttTopics.isVitals('elderly_care/polar_h10/vitals/live'), isTrue);
    expect(MqttTopics.isAlert('elderly_care/polar_h10/alert'), isTrue);
    expect(MqttTopics.isStatus('elderly_care/service/status'), isTrue);
    expect(MqttTopics.isVitals('ecg/vitals'), isFalse);
  });
}
