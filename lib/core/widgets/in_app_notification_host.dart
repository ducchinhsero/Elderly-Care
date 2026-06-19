import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../providers/vitals_provider.dart';
import '../services/notification_service.dart';

class InAppNotificationHost extends ConsumerStatefulWidget {
  final Widget child;

  const InAppNotificationHost({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<InAppNotificationHost> createState() =>
      _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost> {
  StreamSubscription<AppNotificationEvent>? _subscription;
  AppNotificationEvent? _event;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _subscription =
        ref.read(notificationServiceProvider).notificationStream.listen(_show);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _show(AppNotificationEvent event) {
    if (!mounted) return;
    setState(() => _event = event);
    _hideTimer?.cancel();
    _hideTimer = Timer(
      event.isCritical
          ? const Duration(seconds: 12)
          : const Duration(seconds: 8),
      () {
        if (mounted) setState(() => _event = null);
      },
    );
  }

  void _dismiss() {
    _hideTimer?.cancel();
    setState(() => _event = null);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 18,
          right: 18,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: event == null
                  ? const SizedBox.shrink()
                  : _NotificationCard(
                      key: ValueKey(event.timestamp.microsecondsSinceEpoch),
                      event: event,
                      onDismiss: _dismiss,
                      onOpenAlerts: () {
                        _dismiss();
                        context.go('/alerts');
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationEvent event;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAlerts;

  const _NotificationCard({
    super.key,
    required this.event,
    required this.onDismiss,
    required this.onOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final level = event.level.toUpperCase();
    final color = AppColors.fromAlertLevel(level);
    final bgColor = AppColors.backgroundFromAlertLevel(level);
    final darkColor = AppColors.darkFromAlertLevel(level);
    final icon = level == 'CRITICAL'
        ? Icons.report_rounded
        : level == 'ALERT'
            ? Icons.warning_amber_rounded
            : Icons.info_outline_rounded;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, minWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color, width: level == 'CRITICAL' ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: darkColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: darkColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: darkColor.withValues(alpha: 0.88),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: onOpenAlerts,
                            icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 18),
                            label: const Text('Xem cảnh báo'),
                            style: TextButton.styleFrom(
                              foregroundColor: darkColor,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: darkColor,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, color: darkColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
