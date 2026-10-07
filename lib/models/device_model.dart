class DeviceModel {
  final int id;
  final String name;
  final String deviceType;
  final bool isOnline;
  final int batteryLevel;
  final DateTime? lastSeen;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.isOnline,
    required this.batteryLevel,
    this.lastSeen,
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
