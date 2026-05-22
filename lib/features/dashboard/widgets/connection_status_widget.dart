import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/services/websocket_service.dart';

/// Chấm tròn trạng thái kết nối — tự chọn MQTT hoặc WebSocket theo role
class ConnectionStatusWidget extends ConsumerWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final isRemote = storage.isCaregiver;

    if (isRemote) {
      // Remote mode → hiển thị WebSocket state
      final wsState = ref.watch(wsConnectionStateProvider);
      return wsState.when(
        data: (state) => _buildWsDot(context, state),
        loading: () => _buildWsDot(context, WsConnectionState.connecting),
        error: (_, __) => _buildWsDot(context, WsConnectionState.disconnected),
      );
    } else {
      // Local mode → hiển thị MQTT state
      final mqttState = ref.watch(mqttConnectionStateProvider);
      return mqttState.when(
        data: (state) => _buildMqttDot(context, state),
        loading: () => _buildMqttDot(context, MqttConnectionState.connecting),
        error: (_, __) => _buildMqttDot(context, MqttConnectionState.disconnected),
      );
    }
  }

  Widget _buildMqttDot(BuildContext context, MqttConnectionState state) {
    Color color;
    String text;
    switch (state) {
      case MqttConnectionState.connected:
        color = AppColors.safe;
        text = AppStrings.connected;
        break;
      case MqttConnectionState.connecting:
        color = AppColors.watch;
        text = AppStrings.connecting;
        break;
      case MqttConnectionState.reconnecting:
        color = AppColors.watch;
        text = AppStrings.reconnecting;
        break;
      case MqttConnectionState.disconnected:
        color = AppColors.critical;
        text = AppStrings.disconnected;
        break;
    }
    return _dot(context, color, text);
  }

  Widget _buildWsDot(BuildContext context, WsConnectionState state) {
    Color color;
    String text;
    switch (state) {
      case WsConnectionState.connected:
        color = AppColors.safe;
        text = AppStrings.wsConnected;
        break;
      case WsConnectionState.connecting:
        color = AppColors.watch;
        text = AppStrings.connecting;
        break;
      case WsConnectionState.reconnecting:
        color = AppColors.watch;
        text = AppStrings.wsReconnecting;
        break;
      case WsConnectionState.disconnected:
        color = AppColors.critical;
        text = AppStrings.wsDisconnected;
        break;
    }
    return _dot(context, color, text);
  }

  Widget _dot(BuildContext context, Color color, String text) {
    return Tooltip(
      message: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
