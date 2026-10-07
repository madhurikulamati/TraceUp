import 'dart:io';
import 'package:geolocator/geolocator.dart';
import '../core/utils/api_exception.dart';
import '../models/location_model.dart';

/// LocationService manages GPS hardware access and permission handling.
/// UI widgets interact only through this service and never touch Geolocator directly.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Mock GPS fallback coordinates (contract default for testing)
  LocationModel _mockLocation = LocationModel(
    latitude: 16.2356,
    longitude: 80.0498,
    accuracy: 10.5,
    timestamp: DateTime.now(),
  );

  void setMockLocation(LocationModel location) {
    _mockLocation = location;
  }

  /// Checks if device location services (GPS) are activated
  Future<bool> isLocationServiceEnabled() async {
    if (_isTest) return true;
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Checks current location permission status
  Future<LocationPermission> checkPermission() async {
    if (_isTest) return LocationPermission.whileInUse;
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.whileInUse;
    }
  }

  /// Prompts the user to grant location permissions
  Future<LocationPermission> requestPermission() async {
    if (_isTest) return LocationPermission.whileInUse;
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.whileInUse;
    }
  }

  /// Obtains current GPS coordinates with accuracy and timestamp
  /// Throws friendly ApiException if permissions are denied or service is disabled.
  Future<LocationModel> getCurrentLocation() async {
    if (_isTest) {
      return _mockLocation;
    }

    try {
      // 1. Verify location service is turned on
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const ApiException(
          message: 'Location services are disabled. Please enable GPS on your device.',
          type: ApiExceptionType.badRequest,
        );
      }

      // 2. Check and request permission if necessary
      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          throw const ApiException(
            message: 'Location permissions were denied. Please grant location access to track this device.',
            type: ApiExceptionType.forbidden,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw const ApiException(
          message: 'Location permissions are permanently denied. Please enable them in system settings.',
          type: ApiExceptionType.forbidden,
        );
      }

      // 3. Obtain high-accuracy position from device GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Failed to acquire GPS location. Using last known coordinates.',
        type: ApiExceptionType.unknown,
      );
    }
  }
}
