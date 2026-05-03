/// Hằng số MQTT topics — mapping 1:1 với Jetson Nano publisher
class MqttTopics {
  MqttTopics._();

  /// Kết quả inference vitals (mỗi 30 giây)
  static const String vitals = 'ecg/vitals';

  /// Alert khi có mức ≥ ALERT
  static const String alert = 'ecg/alert';

  /// Trạng thái gateway (online/offline)
  static const String status = 'ecg/status';

  /// Tất cả topics cần subscribe
  static const List<String> allTopics = [vitals, alert, status];
}
