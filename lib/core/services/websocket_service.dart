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
  WebSocket? _vitalsWs;
  WebSocket? _alertsWs;
  final _vitalsController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertsController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  WsConnectionState _connectionState = WsConnectionState.disconnected;
  Timer? _reconnectTimer;
  Timer? _alertReconnectTimer;
  Timer? _pingTimer;
  bool _autoReconnect = true;

  String _serverUrl = '';
  String _apiKey = '';

  // ─── Streams ───
  Stream<Map<String, dynamic>> get vitalsStream => _vitalsController.stream;
  Stream<Map<String, dynamic>> get alertsStream => _alertsController.stream;
  Stream<WsConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  WsConnectionState get connectionState => _connectionState;

  /// Cấu hình server URL
  void configure({
    required String serverUrl,
    String? apiKey,
    String? accessCode,
    bool autoReconnect = true,
  }) {
    _serverUrl = serverUrl;
    _apiKey = apiKey?.trim() ?? '';
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

      _vitalsWs = await WebSocket.connect(
        _buildVitalsUrl(wsUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      _updateConnectionState(WsConnectionState.connected);

      // Listen for messages
      _vitalsWs!.listen(
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
        if (_vitalsWs != null && _vitalsWs!.readyState == WebSocket.open) {
          _vitalsWs!.add(jsonEncode({'type': 'ping'}));
        }
        if (_alertsWs != null && _alertsWs!.readyState == WebSocket.open) {
          _alertsWs!.add(jsonEncode({'type': 'ping'}));
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
    _alertReconnectTimer?.cancel();
    _pingTimer?.cancel();
    _autoReconnect = false;
    _vitalsWs?.close();
    _alertsWs?.close();
    _vitalsWs = null;
    _alertsWs = null;
    _updateConnectionState(WsConnectionState.disconnected);
  }

  /// Káº¿t ná»‘i kÃªnh cáº£nh bÃ¡o nghiÃªm trá»ng cho caregiver.
  Future<bool> connectAlerts({
    String? patientId,
    String? caregiverId,
  }) async {
    if (_serverUrl.isEmpty) return false;
    if (_alertsWs != null && _alertsWs!.readyState == WebSocket.open) {
      return true;
    }

    try {
      final wsUrl = _serverUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      _alertsWs = await WebSocket.connect(
        _buildAlertsUrl(
          wsUrl,
          patientId: patientId,
          caregiverId: caregiverId,
        ),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _alertsWs!.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _alertsController.add(json);
          } catch (e) {
            print('WS alerts: Error parsing message: $e');
          }
        },
        onDone: () {
          _alertsWs = null;
          if (_autoReconnect) {
            _scheduleReconnectAlerts(
              patientId: patientId,
              caregiverId: caregiverId,
            );
          }
        },
        onError: (e) {
          print('WS alerts: Error: $e');
          _alertsWs = null;
          if (_autoReconnect) {
            _scheduleReconnectAlerts(
              patientId: patientId,
              caregiverId: caregiverId,
            );
          }
        },
      );
      return true;
    } catch (e) {
      print('WS alerts: Connection error: $e');
      if (_autoReconnect) {
        _scheduleReconnectAlerts(
          patientId: patientId,
          caregiverId: caregiverId,
        );
      }
      return false;
    }
  }

  /// Kiểm tra kết nối
  Future<bool> testConnection(String serverUrl, {String? apiKey}) async {
    try {
      final wsUrl = serverUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final testWs = await WebSocket.connect(
        _buildVitalsUrl(wsUrl, apiKey: apiKey),
      ).timeout(const Duration(seconds: 5));

      testWs.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _buildVitalsUrl(String wsUrl, {String? apiKey}) {
    final key = apiKey?.trim() ?? _apiKey;
    final uri = Uri.parse('$wsUrl/ws/vitals');
    if (key.isEmpty) return uri.toString();
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'api_key': key,
    }).toString();
  }

  String _buildAlertsUrl(
    String wsUrl, {
    String? apiKey,
    String? patientId,
    String? caregiverId,
  }) {
    final key = apiKey?.trim() ?? _apiKey;
    final uri = Uri.parse('$wsUrl/ws/alerts');
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      if (key.isNotEmpty) 'api_key': key,
      if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
      if (caregiverId != null && caregiverId.isNotEmpty)
        'caregiver_id': caregiverId,
    }).toString();
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

  void _scheduleReconnectAlerts({String? patientId, String? caregiverId}) {
    _alertReconnectTimer?.cancel();
    _alertReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_autoReconnect) {
        connectAlerts(patientId: patientId, caregiverId: caregiverId);
      }
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _alertReconnectTimer?.cancel();
    _pingTimer?.cancel();
    _vitalsWs?.close();
    _alertsWs?.close();
    _vitalsController.close();
    _alertsController.close();
    _connectionStateController.close();
  }
}
