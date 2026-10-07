import 'location_model.dart';

enum WebSocketEventType {
  locationUpdate,
  deviceStatus,
  ping,
  pong,
  unknown,
}

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketEvent {
  final WebSocketEventType type;
  final int? deviceId;
  final LocationModel? location;
  final bool? isOnline;
  final int? batteryLevel;
  final Map<String, dynamic> raw;

  const WebSocketEvent({
    required this.type,
    this.deviceId,
    this.location,
    this.isOnline,
    this.batteryLevel,
    this.raw = const {},
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? '';
    WebSocketEventType type;

    switch (typeStr) {
      case 'location_update':
        type = WebSocketEventType.locationUpdate;
        break;
      case 'device_status':
        type = WebSocketEventType.deviceStatus;
        break;
      case 'ping':
        type = WebSocketEventType.ping;
        break;
      case 'pong':
        type = WebSocketEventType.pong;
        break;
      default:
        type = WebSocketEventType.unknown;
    }

    final devId = json['device_id'] as int?;

    LocationModel? loc;
    if (type == WebSocketEventType.locationUpdate || json.containsKey('latitude')) {
      loc = LocationModel.fromJson(json);
    }

    final online = json['is_online'] as bool?;
    final battery = json['battery_level'] as int?;

    return WebSocketEvent(
      type: type,
      deviceId: devId,
      location: loc,
      isOnline: online,
      batteryLevel: battery,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;
}
