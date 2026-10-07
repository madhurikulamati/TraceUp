class LostModeModel {
  final int deviceId;
  final bool isLost;
  final String? phoneNumber;
  final String? message;
  final DateTime? updatedAt;

  const LostModeModel({
    required this.deviceId,
    required this.isLost,
    this.phoneNumber,
    this.message,
    this.updatedAt,
  });

  factory LostModeModel.fromJson(Map<String, dynamic> json) {
    return LostModeModel(
      deviceId: json['device_id'] as int? ?? json['id'] as int? ?? 0,
      isLost: json['is_lost'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
      message: json['message'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'is_lost': isLost,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (message != null) 'message': message,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
