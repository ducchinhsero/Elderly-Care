import 'package:flutter/material.dart';

/// Bảng màu ứng dụng — Material Design 3, tối ưu cho healthcare UI
class AppColors {
  AppColors._();

  // ─── Primary brand colors ───
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryLight = Color(0xFF4DA3FF);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color onPrimary = Colors.white;

  // ─── Surface & background ───
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);

  // ─── Alert level colors ───
  static const Color safe = Color(0xFF4CAF50);
  static const Color safeLight = Color(0xFFE8F5E9);
  static const Color safeDark = Color(0xFF2E7D32);

  static const Color watch = Color(0xFFFFC107);
  static const Color watchLight = Color(0xFFFFF8E1);
  static const Color watchDark = Color(0xFFF57F17);

  static const Color alert = Color(0xFFFF5722);
  static const Color alertLight = Color(0xFFFBE9E7);
  static const Color alertDark = Color(0xFFD84315);

  static const Color critical = Color(0xFFF44336);
  static const Color criticalLight = Color(0xFFFFEBEE);
  static const Color criticalDark = Color(0xFFC62828);

  // ─── Emotion colors ───
  static const Color calm = Color(0xFF66BB6A);
  static const Color stressed = Color(0xFFEF5350);
  static const Color positive = Color(0xFFFFCA28);

  // ─── Activity colors ───
  static const Color rest = Color(0xFF90CAF9);
  static const Color slowWalk = Color(0xFF81C784);
  static const Color walk = Color(0xFF4CAF50);
  static const Color active = Color(0xFFFF9800);

  // ─── Chart colors ───
  static const Color chartLine = Color(0xFF1A73E8);
  static const Color chartFill = Color(0x331A73E8);
  static const Color chartGrid = Color(0xFFE0E0E0);
  static const Color chartNormalZone = Color(0x1A4CAF50);

  // ─── Text ───
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ─── Misc ───
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  /// Trả về màu dựa vào alert level string
  static Color fromAlertLevel(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safe;
      case 'WATCH':
        return watch;
      case 'ALERT':
        return alert;
      case 'CRITICAL':
        return critical;
      default:
        return safe;
    }
  }

  /// Trả về màu nền nhạt dựa vào alert level
  static Color backgroundFromAlertLevel(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safeLight;
      case 'WATCH':
        return watchLight;
      case 'ALERT':
        return alertLight;
      case 'CRITICAL':
        return criticalLight;
      default:
        return safeLight;
    }
  }

  /// Trả về màu tối dựa vào alert level
  static Color darkFromAlertLevel(String level) {
    switch (level.toUpperCase()) {
      case 'SAFE':
        return safeDark;
      case 'WATCH':
        return watchDark;
      case 'ALERT':
        return alertDark;
      case 'CRITICAL':
        return criticalDark;
      default:
        return safeDark;
    }
  }

  /// Màu cho emotion
  static Color fromEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'calm':
        return calm;
      case 'stressed':
        return stressed;
      case 'positive':
        return positive;
      default:
        return calm;
    }
  }

  /// Màu cho activity
  static Color fromActivity(String activity) {
    switch (activity.toLowerCase()) {
      case 'rest':
        return rest;
      case 'slow_walk':
        return slowWalk;
      case 'walk':
        return walk;
      case 'active':
        return active;
      default:
        return rest;
    }
  }
}
