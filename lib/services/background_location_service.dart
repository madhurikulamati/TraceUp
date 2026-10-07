import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../models/tracking_mode_model.dart';
import 'device_service.dart';
import 'location_service.dart';

/// Manages background location tracking, battery-aware interval profiles,
/// and Android Foreground Service notifications.
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  TrackingMode _mode = TrackingMode.balanced;
  TrackingMode get currentMode => _mode;

  int _intervalMinutes = 15;
  int get intervalMinutes => _intervalMinutes;

  DateTime? _lastPingTime;
  DateTime? get lastPingTime => _lastPingTime;

  int _pingsSentCount = 0;
  int get pingsSentCount => _pingsSentCount;

  LocationModel? _lastKnownLocation;
  LocationModel? get lastKnownLocation => _lastKnownLocation;

  int? _activeDeviceId;
  int? get activeDeviceId => _activeDeviceId;

  Timer? _periodicTimer;
  StreamSubscription<Position>? _positionStreamSub;

  final StreamController<bool> _trackingStatusController = StreamController<bool>.broadcast();
  Stream<bool> get trackingStatusStream => _trackingStatusController.stream;

  final StreamController<LocationModel> _locationController = StreamController<LocationModel>.broadcast();
  Stream<LocationModel> get locationStream => _locationController.stream;

  /// Starts background location tracking for [deviceId]
  Future<bool> startTracking({
    required int deviceId,
    TrackingMode? mode,
    int? customIntervalMinutes,
  }) async {
    _activeDeviceId = deviceId;
    if (mode != null) {
      _mode = mode;
      _intervalMinutes = customIntervalMinutes ?? mode.defaultIntervalMinutes;
    } else if (customIntervalMinutes != null) {
      _intervalMinutes = customIntervalMinutes;
    }

    _isTracking = true;
    _trackingStatusController.add(true);

    // Initial immediate sync
    await syncNow();

    // Setup recurring interval sync
    _startIntervalTimer();

    // On real Android, also bind native Geolocator stream if not in test
    if (!_isTest) {
      _setupNativeForegroundStream();
    }

    return true;
  }

  /// Stops background tracking and cancels all active timers/streams
  Future<void> stopTracking() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;

    await _positionStreamSub?.cancel();
    _positionStreamSub = null;

    _isTracking = false;
    _trackingStatusController.add(false);
  }

  /// Updates the tracking mode profile (e.g. Balanced, High Frequency, Battery Saver)
  Future<void> setTrackingMode(TrackingMode mode) async {
    _mode = mode;
    _intervalMinutes = mode.defaultIntervalMinutes;

    if (_isTracking) {
      _startIntervalTimer();
      if (!_isTest) {
        _setupNativeForegroundStream();
      }
    }
  }

  /// Sets a custom tracking interval in minutes
  Future<void> setCustomInterval(int minutes) async {
    _intervalMinutes = minutes.clamp(1, 1440);
    if (_isTracking) {
      _startIntervalTimer();
    }
  }

  /// Performs an immediate location sync and transmits to server
  Future<LocationModel?> syncNow() async {
    final devId = _activeDeviceId ?? 101;

    try {
      final loc = await _locationService.getCurrentLocation();
      await _deviceService.sendDeviceLocation(deviceId: devId, location: loc);

      _lastKnownLocation = loc;
      _lastPingTime = DateTime.now();
      _pingsSentCount++;

      if (!_locationController.isClosed) {
        _locationController.add(loc);
      }

      return loc;
    } catch (e) {
      debugPrint('Background location sync failed: $e');
      return null;
    }
  }

  void _startIntervalTimer() {
    _periodicTimer?.cancel();
    if (_isTest) return;
    final duration = Duration(minutes: _intervalMinutes);

    _periodicTimer = Timer.periodic(duration, (_) {
      syncNow();
    });
  }

  void _setupNativeForegroundStream() {
    try {
      _positionStreamSub?.cancel();

      final accuracy = _mode == TrackingMode.active
          ? LocationAccuracy.high
          : _mode == TrackingMode.balanced
              ? LocationAccuracy.medium
              : LocationAccuracy.low;

      final locationSettings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: _mode.distanceFilterMeters,
        intervalDuration: Duration(minutes: _intervalMinutes),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TraceUp Protection Active',
          notificationText: 'Securing and tracking your device location in background',
          enableWakeLock: true,
        ),
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final loc = LocationModel(
            deviceId: _activeDeviceId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );

          if (_activeDeviceId != null) {
            _deviceService.sendDeviceLocation(deviceId: _activeDeviceId!, location: loc);
          }

          _lastKnownLocation = loc;
          _lastPingTime = DateTime.now();
          _pingsSentCount++;

          if (!_locationController.isClosed) {
            _locationController.add(loc);
          }
        },
        onError: (err) {
          debugPrint('Geolocator position stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Native foreground stream setup failed: $e');
    }
  }

  void dispose() {
    stopTracking();
    _trackingStatusController.close();
    _locationController.close();
  }
}
