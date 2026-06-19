import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class AppNotificationEvent {
  final String level;
  final String title;
  final String body;
  final DateTime timestamp;

  const AppNotificationEvent({
    required this.level,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  bool get isCritical => level.toUpperCase() == 'CRITICAL';
}

/// Lightweight local notification bridge.
///
/// This currently provides an in-app notification stream plus best-effort
/// sound/haptic/vibration. Native OS notifications can be added later without
/// changing callers.
class NotificationService {
  final _notificationController =
      StreamController<AppNotificationEvent>.broadcast();
  bool _initialized = false;

  Stream<AppNotificationEvent> get notificationStream =>
      _notificationController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  Future<void> showCriticalAlert({
    required String title,
    required String body,
  }) async {
    debugPrint('CRITICAL NOTIFICATION: $title - $body');
    await _strongLocalSignal();
  }

  Future<void> showAlert({
    required String title,
    required String body,
  }) async {
    debugPrint('ALERT NOTIFICATION: $title - $body');
    await _shortLocalSignal();
  }

  Future<void> showWatch({
    required String title,
    required String body,
  }) async {
    debugPrint('WATCH NOTIFICATION: $title - $body');
  }

  Future<void> showAlertNotification({
    required String level,
    required String title,
    required String body,
  }) async {
    final normalizedLevel = level.toUpperCase();
    _notificationController.add(AppNotificationEvent(
      level: normalizedLevel,
      title: title,
      body: body,
      timestamp: DateTime.now(),
    ));

    switch (normalizedLevel) {
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

  Future<void> _strongLocalSignal() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 700, 250, 700, 250, 900]);
      }
    } catch (e) {
      debugPrint('NotificationService: strong signal error - $e');
    }
  }

  Future<void> _shortLocalSignal() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.mediumImpact();
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 350);
      }
    } catch (e) {
      debugPrint('NotificationService: short signal error - $e');
    }
  }

  bool isQuietHours() {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 7;
  }

  void dispose() {
    _initialized = false;
    _notificationController.close();
  }
}
