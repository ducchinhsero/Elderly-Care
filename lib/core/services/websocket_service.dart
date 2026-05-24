import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Trạng thái kết nối WebSocket
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Service kết nối WebSocket đến FastAPI cloud (cho người giám sát ở xa)
/// Endpoint: ws://{cloud_server}/ws/vitals
class WebSocketService {
  WebSocket? _ws;
  final _vitalsController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  WsConnectionState _connectionState = WsConnectionState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _autoReconnect = true;

  String _serverUrl = '';
  String _accessCode = '';

  // ─── Streams ───
  Stream<Map<String, dynamic>> get vitalsStream => _vitalsController.stream;
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  WsConnectionState get connectionState => _connectionState;

  /// Cấu hình server URL
  void configure({
    required String serverUrl,
    String? accessCode,
    bool autoReconnect = true,
  }) {
    _serverUrl = serverUrl;
    _accessCode = accessCode?.trim() ?? '';
    _autoReconnect = autoReconnect;
  }

  /// Kết nối WebSocket
  Future<bool> connect() async {
    if (_connectionState == WsConnectionState.connected) return true;
    if (_serverUrl.isEmpty) return false;

    _updateConnectionState(WsConnectionState.connecting);

    try {
      // Chuyển http(s):// thành ws(s)://
      final wsUrl = _serverUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      _ws = await WebSocket.connect(
        '$wsUrl/ws/vitals',
        headers: {
          'Accept': 'application/json',
          if (_accessCode.isNotEmpty) 'X-Access-Code': _accessCode,
        },
      ).timeout(const Duration(seconds: 10));

      _updateConnectionState(WsConnectionState.connected);

      // Listen for messages
      _ws!.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _vitalsController.add(json);
          } catch (e) {
            print('WS: Error parsing message: $e');
          }
        },
        onDone: () {
          print('WS: Connection closed');
          _updateConnectionState(WsConnectionState.disconnected);
          if (_autoReconnect) _scheduleReconnect();
        },
        onError: (e) {
          print('WS: Error: $e');
          _updateConnectionState(WsConnectionState.disconnected);
          if (_autoReconnect) _scheduleReconnect();
        },
      );

      // Ping mỗi 30 giây để giữ kết nối
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_ws != null && _ws!.readyState == WebSocket.open) {
          _ws!.add(jsonEncode({'type': 'ping'}));
        }
      });

      return true;
    } catch (e) {
      print('WS: Connection error: $e');
      _updateConnectionState(WsConnectionState.disconnected);
      if (_autoReconnect) _scheduleReconnect();
      return false;
    }
  }

  /// Ngắt kết nối
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _autoReconnect = false;
    _ws?.close();
    _ws = null;
    _updateConnectionState(WsConnectionState.disconnected);
  }

  /// Kiểm tra kết nối
  Future<bool> testConnection(String serverUrl) async {
    try {
      final wsUrl = serverUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final testWs = await WebSocket.connect(
        '$wsUrl/ws/vitals',
      ).timeout(const Duration(seconds: 5));

      testWs.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Private ───

  void _updateConnectionState(WsConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_connectionState != WsConnectionState.connected) {
        _updateConnectionState(WsConnectionState.reconnecting);
        connect();
      }
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _ws?.close();
    _vitalsController.close();
    _connectionStateController.close();
  }
}
