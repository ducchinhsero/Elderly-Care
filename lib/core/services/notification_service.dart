import 'package:flutter/foundation.dart';

/// Service quản lý push notification (FCM + local)
/// Đơn giản hóa — Firebase cần setup riêng cho từng platform
class NotificationService {
  bool _initialized = false;

  /// Khởi tạo notification service
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Firebase initialization sẽ được thực hiện ở main.dart
      // Ở đây chỉ setup notification channels
      _initialized = true;
      debugPrint('NotificationService: Initialized');
    } catch (e) {
      debugPrint('NotificationService: Init error - $e');
    }
  }

  /// Hiển thị notification cho CRITICAL alert
  Future<void> showCriticalAlert({
    required String title,
    required String body,
  }) async {
    debugPrint('🚨 CRITICAL NOTIFICATION: $title - $body');
    // TODO: Implement actual notification khi Firebase được setup
    // - Heads-up notification
    // - Âm thanh cảnh báo
    // - Vibration liên tục
  }

  /// Hiển thị notification cho ALERT
  Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    debugPrint('⚠️ ALERT NOTIFICATION: $title - $body');
    // TODO: Implement notification thường
  }

  /// Hiển thị notification cho WATCH (badge only)
  Future<void> showWatch({
    required String title,
    required String body,
  }) async {
    debugPrint('👀 WATCH NOTIFICATION: $title - $body');
    // TODO: Badge only, không âm thanh
  }

  /// Hiển thị notification dựa vào alert level
  Future<void> showAlertNotification({
    required String level,
    required String title,
    required String body,
  }) async {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        await showCriticalAlert(title: title, body: body);
        break;
      case 'ALERT':
        await showAlert(title: title, body: body);
        break;
      case 'WATCH':
        await showWatch(title: title, body: body);
        break;
    }
  }

  /// Kiểm tra giờ im lặng (22:00 - 07:00)
  bool isQuietHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 22 || hour < 7;
  }

  void dispose() {
    _initialized = false;
  }
}
