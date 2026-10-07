import '../models/device_model.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_exception.dart';
import 'api_service.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final ApiService _apiService = ApiService();

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
      await Future.delayed(const Duration(milliseconds: 150));
      return List.unmodifiable(_mockDevices);
    }

    try {
      final response = await _apiService.get(ApiConstants.devicesEndpoint);
      if (response is List) {
        return response
            .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  Future<DeviceModel> getDeviceById(int id) async {
    if (ApiConstants.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _mockDevices.firstWhere(
        (d) => d.id == id,
        orElse: () => _mockDevices.first,
      );
    }

    try {
      final response = await _apiService.get(ApiConstants.deviceDetailEndpoint(id));
      if (response is Map<String, dynamic>) {
        return DeviceModel.fromJson(response);
      }
      throw ApiException.fromStatusCode(404, 'Device not found');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  Future<DeviceModel> addDevice({
    required String name,
    required String deviceType,
  }) async {
    if (ApiConstants.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final newDevice = DeviceModel(
        id: 100 + _mockDevices.length + 1,
        name: name.trim(),
        deviceType: deviceType,
        isOnline: true,
        batteryLevel: 100,
        lastSeen: DateTime.now(),
      );
      _mockDevices.add(newDevice);
      return newDevice;
    }

    try {
      final response = await _apiService.post(
        ApiConstants.devicesEndpoint,
        data: {
          'name': name.trim(),
          'device_type': deviceType,
        },
      );

      if (response is Map<String, dynamic>) {
        return DeviceModel.fromJson(response);
      }
      throw ApiException.invalidResponse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  Future<bool> deleteDevice(int id) async {
    if (ApiConstants.isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      _mockDevices.removeWhere((d) => d.id == id);
      return true;
    }

    try {
      await _apiService.delete(ApiConstants.deviceDetailEndpoint(id));
      return true;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }
}
