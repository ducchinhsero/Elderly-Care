import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../constants/mqtt_topics.dart';

/// Trạng thái kết nối MQTT
enum MqttConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Service quản lý kết nối MQTT đến Mosquitto broker
class MqttService {
  MqttServerClient? _client;
  final _vitalsController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();

  MqttConnectionState _connectionState = MqttConnectionState.disconnected;
  Timer? _reconnectTimer;
  bool _autoReconnect = true;

  String _host = '192.168.1.100';
  int _port = 1883;
  String _clientId = 'elder_health_flutter';

  // ─── Streams ───
  Stream<Map<String, dynamic>> get vitalsStream => _vitalsController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  MqttConnectionState get connectionState => _connectionState;

  /// Cấu hình connection
  void configure({
    required String host,
    int port = 1883,
    String? clientId,
    bool autoReconnect = true,
  }) {
    _host = host;
    _port = port;
    if (clientId != null) _clientId = clientId;
    _autoReconnect = autoReconnect;
  }

  /// Kết nối đến MQTT broker
  Future<bool> connect() async {
    if (_connectionState == MqttConnectionState.connected) return true;

    _updateConnectionState(MqttConnectionState.connecting);

    try {
      _client = MqttServerClient.withPort(_host, _clientId, _port);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = _autoReconnect;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .withWillTopic('ecg/client_status')
          .withWillMessage('offline')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      await _client!.connect();

      if (_client!.connectionStatus!.state ==
          MqttConnectionState.connected) {
        _subscribeToTopics();
        _updateConnectionState(MqttConnectionState.connected);
        return true;
      }
    } catch (e) {
      print('MQTT connection error: $e');
      _updateConnectionState(MqttConnectionState.disconnected);
      if (_autoReconnect) _scheduleReconnect();
    }
    return false;
  }

  /// Subscribe tất cả topics
  void _subscribeToTopics() {
    for (final topic in MqttTopics.allTopics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final payload = MqttPublishPayload.bytesToStringAsString(
            (msg.payload as MqttPublishMessage).payload.message);

        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          _routeMessage(msg.topic, json);
        } catch (e) {
          print('Error parsing MQTT message on ${msg.topic}: $e');
        }
      }
    });
  }

  /// Route message đến đúng stream controller
  void _routeMessage(String topic, Map<String, dynamic> json) {
    switch (topic) {
      case MqttTopics.vitals:
        _vitalsController.add(json);
        break;
      case MqttTopics.alert:
        _alertController.add(json);
        break;
      case MqttTopics.status:
        _statusController.add(json);
        break;
    }
  }

  /// Ngắt kết nối
  void disconnect() {
    _reconnectTimer?.cancel();
    _autoReconnect = false;
    _client?.disconnect();
    _updateConnectionState(MqttConnectionState.disconnected);
  }

  /// Kiểm tra kết nối
  Future<bool> testConnection(String host, int port) async {
    final testClient =
        MqttServerClient.withPort(host, '${_clientId}_test', port);
    testClient.logging(on: false);
    testClient.keepAlivePeriod = 10;
    testClient.connectTimeoutPeriod = 5000;

    try {
      final connMessage = MqttConnectMessage()
          .withClientIdentifier('${_clientId}_test')
          .startClean();
      testClient.connectionMessage = connMessage;

      await testClient.connect();
      final success = testClient.connectionStatus!.state ==
          MqttConnectionState.connected;
      testClient.disconnect();
      return success;
    } catch (e) {
      return false;
    }
  }

  // ─── Private helpers ───

  void _onConnected() {
    print('MQTT: Connected to $_host:$_port');
    _updateConnectionState(MqttConnectionState.connected);
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');
    _updateConnectionState(MqttConnectionState.disconnected);
    if (_autoReconnect) _scheduleReconnect();
  }

  void _onAutoReconnect() {
    print('MQTT: Auto-reconnecting...');
    _updateConnectionState(MqttConnectionState.reconnecting);
  }

  void _onAutoReconnected() {
    print('MQTT: Auto-reconnected');
    _subscribeToTopics();
    _updateConnectionState(MqttConnectionState.connected);
  }

  void _updateConnectionState(MqttConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_connectionState != MqttConnectionState.connected) {
        connect();
      }
    });
  }

  /// Giải phóng tài nguyên
  void dispose() {
    _reconnectTimer?.cancel();
    _client?.disconnect();
    _vitalsController.close();
    _alertController.close();
    _statusController.close();
    _connectionStateController.close();
  }
}
