/// MQTT topics matching the Edge AI backend publisher.
class MqttTopics {
  MqttTopics._();

  static const String prefix = 'elderly_care';

  /// Realtime vitals from any patient, e.g. elderly_care/polar_h10/vitals/live.
  static const String vitals = '$prefix/+/vitals/live';

  /// Retained alert from any patient, e.g. elderly_care/polar_h10/alert.
  static const String alert = '$prefix/+/alert';

  /// Edge service online/offline status.
  static const String status = '$prefix/service/status';

  static const List<String> allTopics = [vitals, alert, status];

  static bool isVitals(String topic) =>
      topic.startsWith('$prefix/') && topic.endsWith('/vitals/live');

  static bool isAlert(String topic) =>
      topic.startsWith('$prefix/') && topic.endsWith('/alert');

  static bool isStatus(String topic) => topic == status;
}
