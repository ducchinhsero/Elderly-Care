/// Tất cả string tiếng Việt cho ứng dụng
/// Ngôn ngữ mặc định: Tiếng Việt
class AppStrings {
  AppStrings._();

  // ─── App ───
  static const String appName = 'Giám Sát Sức Khỏe';
  static const String appSubtitle = 'Theo dõi sức khỏe người cao tuổi';

  // ─── Role Selection (Onboarding) ───
  static const String roleSelectionTitle = 'Kết nối bằng mã';
  static const String roleSelectionSubtitle =
      'Nhập mã thiết bị hoặc mã truy cập trước khi vào màn hình theo dõi';
  static const String roleWearer = 'Người đeo';
  static const String roleWearerDesc =
      'Nhập mã thiết bị Raspberry/edge đang xử lý dữ liệu tại chỗ.';
  static const String roleCaregiver = 'Người giám sát';
  static const String roleCaregiverDesc =
      'Nhập mã truy cập được cấp để nhận dữ liệu từ cloud.';
  static const String continueBtn = 'Tiếp tục';
  static const String changeRole = 'Đổi vai trò';
  static const String deviceCode = 'Mã thiết bị';
  static const String deviceCodeHint = 'VD: ELD-2026-001';
  static const String accessCode = 'Mã truy cập';
  static const String accessCodeHint = 'VD: CARE-123-ABC';
  static const String wearerSetupTitle = 'Thông tin người đeo';
  static const String caregiverSetupTitle = 'Thông tin người giám sát';

  // ─── Remote / Cloud ───
  static const String cloudServerUrl = 'Cloud hệ thống';
  static const String cloudServerHint = 'Được cấu hình khi build app';
  static const String monitoringTarget = 'Người được theo dõi';
  static const String caregiverName = 'Tên người giám sát';
  static const String remoteMode = 'Chế độ từ xa';
  static const String localMode = 'Chế độ nội bộ';
  static const String wsConnected = 'WebSocket đã kết nối';
  static const String wsDisconnected = 'WebSocket mất kết nối';
  static const String wsReconnecting = 'Đang kết nối lại WebSocket...';
  static const String remoteCaregiverBanner = '👁️ Đang theo dõi từ xa';
  static const String pairingCode = 'Mã ghép nối';
  static const String enterPairingCode = 'Nhập mã ghép nối từ người đeo';
  static const String generatePairingCode = 'Tạo mã ghép nối';

  // ─── Navigation ───
  static const String navDashboard = 'Tổng quan';
  static const String navAlerts = 'Cảnh báo';
  static const String navHistory = 'Lịch sử';
  static const String navReport = 'Báo cáo';
  static const String navProfile = 'Hồ sơ';
  static const String navSettings = 'Cài đặt';

  // ─── Dashboard ───
  static const String bpm = 'BPM';
  static const String heartRate = 'Nhịp tim';
  static const String hrv = 'HRV';
  static const String rmssd = 'RMSSD';
  static const String lfHfRatio = 'LF/HF';
  static const String activity = 'Hoạt động';
  static const String emotion = 'Cảm xúc';
  static const String lastUpdated = 'Cập nhật lần cuối';
  static const String latency = 'Độ trễ';
  static const String noData = 'Chưa có dữ liệu';
  static const String connecting = 'Đang kết nối...';
  static const String connected = 'Đã kết nối';
  static const String synced = 'Đã đồng bộ';
  static const String realtimeReconnecting = 'Realtime đang kết nối lại';
  static const String disconnected = 'Mất kết nối';
  static const String reconnecting = 'Đang kết nối lại...';
  static const String noDataTimeout = 'Không nhận được dữ liệu > 60 giây';
  static const String last30Min = '30 phút gần nhất';

  // ─── Alert Levels ───
  static const String levelSafe = 'AN TOÀN';
  static const String levelWatch = 'THEO DÕI';
  static const String levelAlert = 'CẢNH BÁO';
  static const String levelCritical = 'NGUY HIỂM';

  static String alertLevelText(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return levelSafe;
      case 'WATCH':
        return levelWatch;
      case 'ALERT':
        return levelAlert;
      case 'CRITICAL':
        return levelCritical;
      default:
        return level;
    }
  }

  // ─── Activities ───
  static const String activityRest = 'Nghỉ ngơi';
  static const String activitySlowWalk = 'Đi bộ chậm';
  static const String activityWalk = 'Đi bộ';
  static const String activityActive = 'Vận động';

  static String activityText(String activity) {
    switch (activity.toLowerCase()) {
      case 'rest':
        return activityRest;
      case 'slow_walk':
        return activitySlowWalk;
      case 'walk':
        return activityWalk;
      case 'active':
        return activityActive;
      default:
        return activity;
    }
  }

  // ─── Emotions ───
  static const String emotionCalm = 'Bình thường';
  static const String emotionStressed = 'Căng thẳng';
  static const String emotionPositive = 'Vui vẻ';

  static String emotionText(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'calm':
        return emotionCalm;
      case 'stressed':
        return emotionStressed;
      case 'positive':
        return emotionPositive;
      default:
        return emotion;
    }
  }

  // ─── Alert Types ───
  static String alertTypeTitle(String type) {
    switch (type.toUpperCase()) {
      case 'TACHYCARDIA':
      case 'TACHYCARDIA_AT_REST':
        return 'Nhịp tim nhanh bất thường';
      case 'BRADYCARDIA':
        return 'Nhịp tim chậm bất thường';
      case 'IRREGULAR_RHYTHM':
      case 'RHYTHM_ALERT':
      case 'AFIB_SUSPICION':
        return 'Nhịp tim không đều';
      case 'VERY_LOW_HRV':
        return 'Biến thiên nhịp tim rất thấp';
      case 'FALL_DETECTED':
      case 'FALL_CANDIDATE':
      case 'STRONG_FALL':
        return '⚠️ Phát hiện ngã!';
      default:
        return 'Cảnh báo sức khỏe';
    }
  }

  static String alertTypeDetail(String type,
      {double? hr, double? rmssd, String? activity}) {
    switch (type.toUpperCase()) {
      case 'TACHYCARDIA':
      case 'TACHYCARDIA_AT_REST':
        final actText = activity != null ? activityText(activity) : '';
        return 'Nhịp tim nhanh ${hr?.toStringAsFixed(0) ?? '--'} BPM khi $actText';
      case 'BRADYCARDIA':
        return 'Nhịp tim chậm ${hr?.toStringAsFixed(0) ?? '--'} BPM';
      case 'IRREGULAR_RHYTHM':
      case 'RHYTHM_ALERT':
      case 'AFIB_SUSPICION':
        return 'Nhịp tim không đều (có thể rung nhĩ)';
      case 'VERY_LOW_HRV':
        return 'Biến thiên nhịp tim rất thấp ${rmssd?.toStringAsFixed(1) ?? '--'} ms';
      case 'FALL_DETECTED':
      case 'FALL_CANDIDATE':
      case 'STRONG_FALL':
        return 'Phát hiện ngã! Kiểm tra ngay!';
      default:
        return 'Cần theo dõi sức khỏe';
    }
  }

  // ─── Alert Center ───
  static const String alertCenter = 'Trung tâm cảnh báo';
  static const String tabNew = 'Mới';
  static const String tabToday = 'Hôm nay';
  static const String tab7Days = '7 ngày qua';
  static const String noAlerts = 'Không có cảnh báo nào';
  static const String noAlertsDesc = 'Mọi chỉ số đang bình thường';
  static const String viewDetails = 'Xem chi tiết';
  static const String markAsRead = 'Đã đọc';
  static const String minutesAgo = ' phút trước';
  static const String hoursAgo = ' giờ trước';
  static const String daysAgo = ' ngày trước';
  static const String justNow = 'Vừa xong';

  // ─── History ───
  static const String history = 'Lịch sử';
  static const String today = 'Hôm nay';
  static const String days7 = '7 ngày';
  static const String days30 = '30 ngày';
  static const String tabHeartRate = 'Nhịp tim';
  static const String tabHRV = 'HRV';
  static const String tabEmotion = 'Cảm xúc';
  static const String tabActivity = 'Hoạt động';
  static const String avgHR = 'TB';
  static const String minHR = 'Thấp nhất';
  static const String maxHR = 'Cao nhất';
  static const String normalPercent = '% trong ngưỡng';
  static const String normalRange = 'Ngưỡng bình thường';

  // ─── Report ───
  static const String healthReport = 'Báo cáo sức khỏe';
  static const String dailyReport = 'Báo cáo ngày';
  static const String weeklyReport = 'Báo cáo tuần';
  static const String healthScore = 'Điểm sức khỏe';
  static const String scoreGood = 'TỐT';
  static const String scoreAverage = 'TRUNG BÌNH';
  static const String scoreNeedAttention = 'CẦN CHÚ Ý';
  static const String overview = 'Tổng quan';
  static const String insights = 'Nhận xét tự động';
  static const String comparison = 'So sánh tuần trước';
  static const String exportPdf = 'Xuất PDF';
  static const String share = 'Chia sẻ';
  static const String avgAlerts = 'Số cảnh báo';
  static const String exerciseTime = 'Thời gian vận động';

  // ─── Profile ───
  static const String profile = 'Hồ sơ';
  static const String name = 'Họ tên';
  static const String age = 'Tuổi';
  static const String comorbidities = 'Bệnh nền';
  static const String medications = 'Thuốc đang dùng';
  static const String personalThresholds = 'Ngưỡng cá nhân hóa';
  static const String calibrateBaseline = 'Calibrate baseline';
  static const String calibrating = 'Đang calibrate...';
  static const String calibrateSuccess =
      'Calibrate thành công! Ngưỡng đã cập nhật';
  static const String calibrateExplain =
      'Vui lòng ngồi nghỉ yên 30 phút để hệ thống đo baseline nhịp tim và HRV của bạn.';
  static const String notCalibrated = 'Chưa calibrate';
  static const String calibrated = 'Đã calibrate';
  static const String needRecalibrate = 'Cần calibrate lại';
  static const String emergencyContact = 'Liên hệ khẩn cấp';
  static const String emergencyName = 'Tên người thân';
  static const String emergencyPhone = 'Số điện thoại';

  // ─── Comorbidities ───
  static const List<String> comorbidityOptions = [
    'Tăng huyết áp',
    'Rung nhĩ đã biết',
    'Suy tim',
    'Tiểu đường type 2',
    'Máy tạo nhịp',
    'Đang dùng chẹn beta',
    'Cường giáp',
  ];

  // ─── Settings ───
  static const String settings = 'Cài đặt';
  static const String connection = 'Kết nối';
  static const String gatewayIp = 'IP Gateway';
  static const String mqttPort = 'MQTT Port';
  static const String testConnection = 'Kiểm tra kết nối';
  static const String autoReconnect = 'Tự động kết nối lại';
  static const String notifications = 'Thông báo';
  static const String notifCritical = 'Thông báo NGUY HIỂM';
  static const String notifAlert = 'Thông báo CẢNH BÁO';
  static const String notifWatch = 'Thông báo THEO DÕI';
  static const String quietHours = 'Giờ im lặng';
  static const String quietHoursDesc = '22:00 - 07:00';
  static const String emergencyCall = 'Số điện thoại gọi khẩn';
  static const String displayThresholds = 'Ngưỡng hiển thị';
  static const String hrNormalLow = 'HR bình thường (thấp)';
  static const String hrNormalHigh = 'HR bình thường (cao)';
  static const String autoThresholds = 'Tự động theo bệnh nền';
  static const String autoThresholdsDesc = 'Khuyến nghị BẬT';
  static const String appearance = 'Giao diện';
  static const String darkMode = 'Chế độ tối';
  static const String language = 'Ngôn ngữ';
  static const String vietnamese = 'Tiếng Việt';
  static const String english = 'English';

  // ─── Beat types ───
  static String beatTypeName(String? type) {
    if (type == null) return 'Bình thường';
    switch (type.toUpperCase()) {
      case 'N':
        return 'Bình thường';
      case 'S':
        return 'Nhịp trên thất sớm';
      case 'V':
        return 'Nhịp thất sớm';
      case 'F':
        return 'Nhịp fusion';
      default:
        return type;
    }
  }

  // ─── Common ───
  static const String save = 'Lưu';
  static const String cancel = 'Hủy';
  static const String confirm = 'Xác nhận';
  static const String ok = 'OK';
  static const String error = 'Lỗi';
  static const String retry = 'Thử lại';
  static const String loading = 'Đang tải...';
  static const String ms = 'ms';
  static const String next = 'Tiếp theo';
  static const String back = 'Quay lại';
  static const String skip = 'Bỏ qua';
}
