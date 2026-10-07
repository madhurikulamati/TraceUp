import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/api_constants.dart';
import '../models/location_model.dart';
import '../models/websocket_event_model.dart';
import '../storage/token_storage.dart';

/// Handles real-time bi-directional WebSocket communication for live device tracking.
/// Supports both live Django Channels WebSockets and offline Mock mode.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final TokenStorage _tokenStorage = TokenStorage();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  Timer? _mockTimer;

  int? _activeDeviceId;
  bool _isManualDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WebSocketConnectionStatus _currentStatus = WebSocketConnectionStatus.disconnected;
  WebSocketConnectionStatus get currentStatus => _currentStatus;

  final StreamController<WebSocketConnectionStatus> _statusController =
      StreamController<WebSocketConnectionStatus>.broadcast();
  Stream<WebSocketConnectionStatus> get statusStream => _statusController.stream;

  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  Stream<LocationModel> get locationUpdates => _eventController.stream
      .where((event) => event.location != null)
      .map((event) => event.location!);

  bool get isMock => ApiConstants.isMockMode;

  /// Initiates WebSocket connection for a given [deviceId].
  Future<void> connect(int deviceId) async {
    if (_currentStatus == WebSocketConnectionStatus.connected && _activeDeviceId == deviceId) {
      return;
    }

    _activeDeviceId = deviceId;
    _isManualDisconnect = false;
    _updateStatus(WebSocketConnectionStatus.connecting);

    if (isMock) {
      _startMockMode(deviceId);
      return;
    }

    await _connectReal(deviceId);
  }

  Future<void> _connectReal(int deviceId) async {
    try {
      final token = await _tokenStorage.getAccessToken();
      var uri = ApiConstants.deviceWsUri(deviceId);

      if (token != null && token.isNotEmpty) {
        uri = uri.replace(queryParameters: {'token': token});
      }

      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;

      _reconnectAttempts = 0;
      _updateStatus(WebSocketConnectionStatus.connected);

      _channelSubscription = _channel?.stream.listen(
        (data) {
          _handleIncomingData(data);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleConnectionFailure();
        },
        onDone: () {
          debugPrint('WebSocket connection closed.');
          if (!_isManualDisconnect) {
            _handleConnectionFailure();
          } else {
            _updateStatus(WebSocketConnectionStatus.disconnected);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _handleConnectionFailure();
    }
  }

  void _handleIncomingData(dynamic rawData) {
    try {
      final Map<String, dynamic> json;
      if (rawData is String) {
        json = jsonDecode(rawData) as Map<String, dynamic>;
      } else if (rawData is Map<String, dynamic>) {
        json = rawData;
      } else {
        return;
      }

      final event = WebSocketEvent.fromJson(json);
      _eventController.add(event);
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _handleConnectionFailure() {
    _cleanupChannel();

    if (_isManualDisconnect) {
      _updateStatus(WebSocketConnectionStatus.disconnected);
      return;
    }

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      _updateStatus(WebSocketConnectionStatus.reconnecting);
      final delaySeconds = pow(2, _reconnectAttempts).clamp(1, 30).toInt();

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (!_isManualDisconnect && _activeDeviceId != null) {
          _connectReal(_activeDeviceId!);
        }
      });
    } else {
      _updateStatus(WebSocketConnectionStatus.error);
    }
  }

  /// Sends a live location ping through the active WebSocket channel.
  void sendLocationPing({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
  }) {
    final payload = {
      'type': 'location_update',
      'device_id': _activeDeviceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (isMock) {
      // In mock mode, immediately loop back through event stream
      simulateLocationUpdate(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
      return;
    }

    if (_channel != null && _currentStatus == WebSocketConnectionStatus.connected) {
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  /// Manually emit a location event (used for mock mode and unit tests).
  void simulateLocationUpdate({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    int? deviceId,
  }) {
    final devId = deviceId ?? _activeDeviceId ?? 101;
    final loc = LocationModel(
      deviceId: devId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );

    final event = WebSocketEvent(
      type: WebSocketEventType.locationUpdate,
      deviceId: devId,
      location: loc,
      raw: {
        'type': 'location_update',
        'device_id': devId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    _eventController.add(event);
  }

  /// Starts mock mode with simulated initial connection and periodic updates.
  void _startMockMode(int deviceId) {
    _mockTimer?.cancel();

    // Simulate quick connection handshake
    Timer(const Duration(milliseconds: 300), () {
      if (_isManualDisconnect) return;
      _updateStatus(WebSocketConnectionStatus.connected);

      // Emit initial live event for the device
      simulateLocationUpdate(
        deviceId: deviceId,
        latitude: 16.2356,
        longitude: 80.0498,
        accuracy: 8.5,
      );
    });
  }

  /// Disconnects the active WebSocket session and cleans up resources.
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _mockTimer?.cancel();
    _cleanupChannel();
    _updateStatus(WebSocketConnectionStatus.disconnected);
    _activeDeviceId = null;
  }

  void _cleanupChannel() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _updateStatus(WebSocketConnectionStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Cleans up controllers when shutting down
  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
  }
}
