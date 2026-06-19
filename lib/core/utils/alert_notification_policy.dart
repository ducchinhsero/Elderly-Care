class AlertNotificationPolicy {
  AlertNotificationPolicy._();

  static bool shouldPopup({
    required String type,
    required String level,
  }) {
    final key = type.toLowerCase();
    final normalizedLevel = level.toUpperCase();

    if (key.contains('overall_alert') || key.contains('critical_vitals')) {
      return false;
    }
    if (key.contains('sustained_') || key.contains('critical_hr_immobile')) {
      return normalizedLevel == 'ALERT' ||
          normalizedLevel == 'HIGH' ||
          normalizedLevel == 'CRITICAL';
    }
    if (key.contains('fall')) return true;
    if ((key.contains('afib') ||
            key.contains('af_suspicion') ||
            key.contains('rhythm')) &&
        (normalizedLevel == 'ALERT' ||
            normalizedLevel == 'HIGH' ||
            normalizedLevel == 'CRITICAL')) {
      return true;
    }
    return normalizedLevel == 'CRITICAL' &&
        !key.contains('tachy') &&
        !key.contains('brady') &&
        !key.contains('hr_context');
  }

  static bool bypassesQuietHours({
    required String type,
    required String level,
  }) {
    if (!shouldPopup(type: type, level: level)) return false;
    final key = type.toLowerCase();
    return level.toUpperCase() == 'CRITICAL' ||
        key.contains('fall') ||
        key.contains('sustained_') ||
        key.contains('critical_hr_immobile');
  }
}
