class HealthDisplayMapper {
  HealthDisplayMapper._();

  static const List<String> apiEndpoints = [
    'GET /health',
    'GET /latest-result',
    'GET /history',
    'GET /events',
    'GET /health-report',
    'GET /api/user/{userId}',
    'POST /personal-baseline/update-progressive',
    'GET /guided-baseline/status',
    'POST /guided-baseline/start',
    'POST /guided-baseline/segment/complete',
    'POST /guided-baseline/complete-day',
  ];

  static const List<String> wearerHeaders = ['X-Device-Code'];
  static const List<String> caregiverHeaders = ['X-Access-Code'];

  static const List<AlertMappingInfo> alertMappings = [
    AlertMappingInfo(
      backendType: 'fall, fall_candidate, strong_fall',
      userTitle: 'Nghi ngờ té ngã',
      userAction: 'Kiểm tra người dùng ngay.',
    ),
    AlertMappingInfo(
      backendType: 'afib, rhythm, af_suspicion',
      userTitle: 'Dấu hiệu nhịp tim không đều',
      userAction: 'Theo dõi thêm và trao đổi với nhân viên y tế nếu lặp lại.',
    ),
    AlertMappingInfo(
      backendType: 'ectopy, pvc, pac',
      userTitle: 'Có nhịp đến sớm',
      userAction: 'Theo dõi tần suất, nhất là khi có mệt hoặc hồi hộp.',
    ),
    AlertMappingInfo(
      backendType: 'tachycardia',
      userTitle: 'Nhịp tim nhanh hơn bình thường',
      userAction: 'Nghỉ ngơi, đo lại và kiểm tra triệu chứng.',
    ),
    AlertMappingInfo(
      backendType: 'bradycardia',
      userTitle: 'Nhịp tim chậm hơn bình thường',
      userAction: 'Kiểm tra người dùng nếu chóng mặt, mệt hoặc khó thở.',
    ),
    AlertMappingInfo(
      backendType: 'signal, poor_signal, signal_quality',
      userTitle: 'Tín hiệu đo chưa tốt',
      userAction: 'Chỉnh lại dây đeo/cảm biến rồi đo lại.',
    ),
  ];

  static String levelLabel(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return 'Cần hỗ trợ ngay';
      case 'ALERT':
      case 'HIGH':
        return 'Cần kiểm tra';
      case 'WATCH':
      case 'MEDIUM':
        return 'Cần theo dõi';
      case 'SAFE':
      case 'LOW':
      case 'NORMAL':
        return 'Ổn định';
      default:
        return 'Chưa đủ dữ liệu';
    }
  }

  static String levelAction(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return 'Kiểm tra người dùng ngay. Nếu có đau ngực, khó thở, ngất hoặc té ngã, hãy gọi hỗ trợ y tế.';
      case 'ALERT':
      case 'HIGH':
        return 'Cho người dùng nghỉ, đo lại và ghi nhận triệu chứng. Nếu tình trạng lặp lại, nên trao đổi với nhân viên y tế.';
      case 'WATCH':
      case 'MEDIUM':
        return 'Tiếp tục theo dõi. Kiểm tra lại nếu người dùng thấy mệt, hồi hộp, chóng mặt hoặc khó chịu.';
      case 'SAFE':
      case 'LOW':
      case 'NORMAL':
        return 'Tiếp tục theo dõi như bình thường.';
      default:
        return 'Cần thêm dữ liệu đo tốt trước khi đưa ra nhận định.';
    }
  }

  static String alertTitle(String type) {
    final key = type.toLowerCase();
    if (key.contains('fall')) return 'Nghi ngờ té ngã';
    if (key.contains('afib') ||
        key.contains('rhythm') ||
        key.contains('af_suspicion')) {
      return 'Dấu hiệu nhịp tim không đều';
    }
    if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
      return 'Có nhịp đến sớm';
    }
    if (key.contains('tachy')) return 'Nhịp tim nhanh hơn bình thường';
    if (key.contains('brady')) return 'Nhịp tim chậm hơn bình thường';
    if (key.contains('poor_signal') || key.contains('signal')) {
      return 'Tín hiệu đo chưa tốt';
    }
    if (key.contains('hrv') || key.contains('rmssd')) {
      return 'Cơ thể có dấu hiệu căng thẳng';
    }
    if (key.contains('anomaly')) return 'Có điểm đo cần xem lại';
    return 'Cần chú ý sức khỏe';
  }

  static String alertWhy(String type) {
    final key = type.toLowerCase();
    if (key.contains('fall')) {
      return 'Cảm biến ghi nhận chuyển động giống té ngã.';
    }
    if (key.contains('afib') ||
        key.contains('rhythm') ||
        key.contains('af_suspicion')) {
      return 'Khoảng đo gần đây có mẫu nhịp tim không đều hơn bình thường.';
    }
    if (key.contains('ectopy') || key.contains('pvc') || key.contains('pac')) {
      return 'Hệ thống thấy một số nhịp đến sớm trong cửa sổ đo gần nhất.';
    }
    if (key.contains('tachy')) {
      return 'Nhịp tim đang cao so với bối cảnh đo hiện tại.';
    }
    if (key.contains('brady')) {
      return 'Nhịp tim đang thấp so với bối cảnh đo hiện tại.';
    }
    if (key.contains('poor_signal') || key.contains('signal')) {
      return 'Dữ liệu đo có thể kém tin cậy do tiếp xúc cảm biến chưa tốt.';
    }
    if (key.contains('hrv') || key.contains('rmssd')) {
      return 'Mức biến thiên nhịp tim thấp có thể xuất hiện khi cơ thể mệt hoặc căng thẳng.';
    }
    if (key.contains('anomaly')) {
      return 'Một phần tín hiệu ECG khác với mẫu thường thấy và cần được theo dõi thêm.';
    }
    return 'Backend gửi sự kiện cần theo dõi thêm.';
  }

  static String alertAction(String type, String level) {
    final key = type.toLowerCase();
    if (level.toUpperCase() == 'CRITICAL' || key.contains('fall')) {
      return 'Kiểm tra người dùng ngay.';
    }
    if (key.contains('poor_signal') || key.contains('signal')) {
      return 'Chỉnh lại dây đeo/cảm biến rồi đo lại.';
    }
    if (level.toUpperCase() == 'ALERT') {
      return 'Cho người dùng nghỉ, đo lại và liên hệ nhân viên y tế nếu có triệu chứng.';
    }
    if (level.toUpperCase() == 'WATCH') {
      return 'Theo dõi thêm và kiểm tra lại nếu tình trạng lặp lại.';
    }
    return levelAction(level);
  }

  static String metricLabel(String key) {
    switch (key.toLowerCase()) {
      case 'rmssd':
      case 'hrv':
        return 'Mức phục hồi/căng thẳng cơ thể';
      case 'afib':
      case 'rhythm':
        return 'Dấu hiệu nhịp tim không đều';
      case 'pvc':
      case 'pac':
      case 'ectopy':
        return 'Nhịp đến sớm';
      case 'baseline':
        return 'Mức bình thường của riêng bạn';
      case 'latency':
        return 'Độ trễ dữ liệu';
      default:
        return key;
    }
  }

  static String signalLabel(String value) {
    switch (value.toLowerCase()) {
      case 'good':
        return 'Tín hiệu tốt';
      case 'fair':
        return 'Tín hiệu dùng được';
      case 'poor':
      case 'bad':
        return 'Tín hiệu chưa tốt';
      default:
        return 'Chưa rõ chất lượng tín hiệu';
    }
  }

  static String rhythmSummary(String rhythmLabel, double afibProbability) {
    final key = rhythmLabel.toLowerCase();
    if (key == 'normal') return 'Nhịp tim đang đều';
    if (key.contains('afib') || afibProbability >= 0.28) {
      return 'Có dấu hiệu nhịp tim không đều';
    }
    if (key == 'other_rhythm') return 'Nhịp tim cần theo dõi thêm';
    return 'Đang phân tích nhịp tim';
  }

  static String ectopySummary(String ectopyLabel) {
    final key = ectopyLabel.toLowerCase();
    if (key == 'pvc' || key == 'pac' || key == 'mixed_ectopic') {
      return 'Có nhịp đến sớm';
    }
    if (key == 'none' || key == 'normal') return 'Chưa thấy nhịp đến sớm';
    return 'Chưa đủ dữ liệu về nhịp đến sớm';
  }
}

class AlertMappingInfo {
  final String backendType;
  final String userTitle;
  final String userAction;

  const AlertMappingInfo({
    required this.backendType,
    required this.userTitle,
    required this.userAction,
  });
}
