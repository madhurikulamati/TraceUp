import '../models/device_model.dart';
import '../core/constants/api_constants.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final List<DeviceModel> _mockDevices = [
    DeviceModel(
      id: 101,
      name: 'Rajini Phone',
      deviceType: 'Android',
      isOnline: true,
      batteryLevel: 72,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    DeviceModel(
      id: 102,
      name: 'Work Tablet',
      deviceType: 'Android',
      isOnline: false,
      batteryLevel: 34,
      lastSeen: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Future<List<DeviceModel>> getDevices() async {
    if (ApiConstants.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.unmodifiable(_mockDevices);
    }
    throw UnimplementedError('Real backend integration will be active in Phase 3.');
  }

  Future<DeviceModel> getDeviceById(int id) async {
    if (ApiConstants.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockDevices.firstWhere(
        (d) => d.id == id,
        orElse: () => _mockDevices.first,
      );
    }
    throw UnimplementedError('Real backend integration will be active in Phase 3.');
  }

  Future<DeviceModel> addDevice({
    required String name,
    required String deviceType,
  }) async {
    if (ApiConstants.isMockMode) {
      final newDevice = DeviceModel(
        id: 100 + _mockDevices.length + 1,
        name: name,
        deviceType: deviceType,
        isOnline: true,
        batteryLevel: 100,
        lastSeen: DateTime.now(),
      );
      _mockDevices.add(newDevice);
      return newDevice;
    }
    throw UnimplementedError('Real backend integration will be active in Phase 3.');
  }

  Future<bool> deleteDevice(int id) async {
    if (ApiConstants.isMockMode) {
      _mockDevices.removeWhere((d) => d.id == id);
      return true;
    }
    throw UnimplementedError('Real backend integration will be active in Phase 3.');
  }
}
