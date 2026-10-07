import '../models/device_model.dart';
import '../models/location_model.dart';
import '../models/lost_mode_model.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_exception.dart';
import 'api_service.dart';
import 'location_service.dart';

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

  // --- Phase 5 Location API Methods ---

  /// Sends dynamic GPS location to the backend: POST /devices/{id}/location/
  Future<Map<String, dynamic>> sendDeviceLocation({
    required int deviceId,
    required LocationModel location,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.deviceLocationEndpoint(deviceId),
        data: location.toPostPayload(),
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      throw ApiException.invalidResponse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Retrieves the latest recorded location for a device: GET /devices/{id}/location/
  Future<LocationModel> getDeviceLocation(int deviceId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.deviceLocationEndpoint(deviceId),
      );

      if (response is Map<String, dynamic>) {
        return LocationModel.fromJson(response);
      }
      throw ApiException.invalidResponse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Retrieves historic location updates for a device: GET /devices/{id}/locations/
  Future<List<LocationModel>> getDeviceLocationHistory(int deviceId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.deviceLocationsEndpoint(deviceId),
      );

      if (response is List) {
        return response
            .map((item) => LocationModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Obtains live GPS coordinates from LocationService and uploads them to the server
  Future<LocationModel> syncCurrentLocationToServer({
    required int deviceId,
    LocationService? locationService,
  }) async {
    final service = locationService ?? LocationService();
    // 1. Obtain dynamic coordinates from GPS sensor (not hard-coded)
    final liveLocation = await service.getCurrentLocation();

    // 2. Transmit to backend via POST /devices/{id}/location/
    await sendDeviceLocation(deviceId: deviceId, location: liveLocation);

    return liveLocation;
  }

  /// Triggers sound alert on device: POST /devices/{id}/play-sound/
  Future<Map<String, dynamic>> playSound(int deviceId) async {
    try {
      final response = await _apiService.post(
        ApiConstants.playSoundEndpoint(deviceId),
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'status': 'playing'};
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Cancels remote sound alert on device: POST /devices/{id}/stop-sound/
  Future<Map<String, dynamic>> stopSound(int deviceId) async {
    try {
      final response = await _apiService.post(
        ApiConstants.stopSoundEndpoint(deviceId),
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'status': 'stopped'};
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Retrieves current Lost Mode status: GET /devices/{id}/lost-mode/
  Future<LostModeModel> getLostMode(int deviceId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.lostModeEndpoint(deviceId),
      );

      if (response is Map<String, dynamic>) {
        return LostModeModel.fromJson(response);
      }
      throw ApiException.invalidResponse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Configures or toggles Lost Mode: POST /devices/{id}/lost-mode/
  Future<LostModeModel> setLostMode(
    int deviceId, {
    required bool isLost,
    String? phoneNumber,
    String? message,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.lostModeEndpoint(deviceId),
        data: {
          'is_lost': isLost,
          'phone_number': ?phoneNumber,
          'message': ?message,
        },
      );

      if (response is Map<String, dynamic>) {
        // Also update local mock device if exists
        final index = _mockDevices.indexWhere((d) => d.id == deviceId);
        if (index != -1) {
          _mockDevices[index] = _mockDevices[index].copyWith(
            isLost: isLost,
            lostPhoneNumber: phoneNumber,
            lostMessage: message,
          );
        }

        return LostModeModel.fromJson(response);
      }
      throw ApiException.invalidResponse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Remotely locks device screen: POST /devices/{id}/lock/
  Future<Map<String, dynamic>> lockDevice(int deviceId, {String? lockMessage}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.lockDeviceEndpoint(deviceId),
        data: {
          'lock_message': ?lockMessage,
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return {'status': 'locked'};
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }
}
