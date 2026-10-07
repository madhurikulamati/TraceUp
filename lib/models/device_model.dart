class DeviceModel {
  final int id;
  final String name;
  final String deviceType;
  final bool isOnline;
  final int batteryLevel;
  final DateTime? lastSeen;
  final bool isLost;
  final String? lostPhoneNumber;
  final String? lostMessage;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.isOnline,
    required this.batteryLevel,
    this.lastSeen,
    this.isLost = false,
    this.lostPhoneNumber,
    this.lostMessage,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Device',
      deviceType: json['device_type'] as String? ?? 'Android',
      isOnline: json['is_online'] as bool? ?? false,
      batteryLevel: json['battery_level'] as int? ?? 0,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      isLost: json['is_lost'] as bool? ?? false,
      lostPhoneNumber: json['phone_number'] as String? ?? json['lost_phone_number'] as String?,
      lostMessage: json['message'] as String? ?? json['lost_message'] as String?,
    );
  }

  DeviceModel copyWith({
    int? id,
    String? name,
    String? deviceType,
    bool? isOnline,
    int? batteryLevel,
    DateTime? lastSeen,
    bool? isLost,
    String? lostPhoneNumber,
    String? lostMessage,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      isLost: isLost ?? this.isLost,
      lostPhoneNumber: lostPhoneNumber ?? this.lostPhoneNumber,
      lostMessage: lostMessage ?? this.lostMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_type': deviceType,
      'is_online': isOnline,
      'battery_level': batteryLevel,
      'last_seen': lastSeen?.toIso8601String(),
      'is_lost': isLost,
      if (lostPhoneNumber != null) 'phone_number': lostPhoneNumber,
      if (lostMessage != null) 'message': lostMessage,
    };
  }

  String get formattedLastSeen {
    if (lastSeen == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  bool get isLowBattery => batteryLevel <= 20;
}
