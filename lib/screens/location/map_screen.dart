import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../models/location_model.dart';
import '../../models/valhalla_route_model.dart';
import '../../models/websocket_event_model.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';
import '../../services/valhalla_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/custom_button.dart';

class MapScreen extends StatefulWidget {
  final DeviceModel? device;
  final int? deviceId;

  const MapScreen({
    super.key,
    this.device,
    this.deviceId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DeviceService _deviceService = DeviceService();
  final LocationService _locationService = LocationService();
  final ValhallaService _valhallaService = ValhallaService();
  final WebSocketService _webSocketService = WebSocketService();

  MapLibreMapController? _mapController;
  DeviceModel? _device;
  LocationModel? _currentLocation;
  ValhallaRouteModel? _route;
  bool _isLoading = true;
  bool _isRouting = false;

  WebSocketConnectionStatus _wsStatus = WebSocketConnectionStatus.disconnected;
  StreamSubscription<WebSocketConnectionStatus>? _wsStatusSubscription;
  StreamSubscription<LocationModel>? _wsLocationSubscription;

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _fetchDeviceAndLocation();
    _initWebSocket();
  }

  @override
  void dispose() {
    _wsStatusSubscription?.cancel();
    _wsLocationSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  void _initWebSocket() {
    final id = widget.deviceId ?? widget.device?.id ?? 101;

    _wsStatusSubscription = _webSocketService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _wsStatus = status);
    });

    _wsLocationSubscription = _webSocketService.locationUpdates.listen((loc) {
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
      });
      _updateMapMarker();
    });

    _webSocketService.connect(id);
  }

  Future<void> _fetchDeviceAndLocation() async {
    final id = widget.deviceId ?? widget.device?.id ?? 101;

    try {
      final dev = widget.device ?? await _deviceService.getDeviceById(id);
      final loc = await _deviceService.getDeviceLocation(id);

      if (!mounted) return;
      setState(() {
        _device = dev;
        _currentLocation = loc;
        _isLoading = false;
      });

      _updateMapMarker();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LocationModel(
          deviceId: id,
          latitude: 16.2356,
          longitude: 80.0498,
          accuracy: 10.5,
          timestamp: DateTime.now(),
        );
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _updateMapMarker();
  }

  Future<void> _updateMapMarker() async {
    if (_mapController == null || _currentLocation == null || _isTest) return;

    try {
      final target = LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 14.5),
        ),
      );

      await _mapController!.clearSymbols();
      await _mapController!.addSymbol(
        SymbolOptions(
          geometry: target,
          iconImage: 'marker-15',
          iconSize: 1.8,
          textField: _device?.name ?? 'Device',
          textOffset: const Offset(0, 1.2),
          textColor: '#1E3A8A',
        ),
      );
    } catch (_) {}
  }

  Future<void> _fetchValhallaRoute() async {
    if (_currentLocation == null) return;

    setState(() => _isRouting = true);

    try {
      // 1. Get user current location
      final userLoc = await _locationService.getCurrentLocation();

      // 2. Query Valhalla routing engine
      final route = await _valhallaService.getRoute(
        startLat: userLoc.latitude,
        startLon: userLoc.longitude,
        endLat: _currentLocation!.latitude,
        endLon: _currentLocation!.longitude,
      );

      if (!mounted) return;
      setState(() {
        _route = route;
        _isRouting = false;
      });

      _showRouteBottomSheet(route);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRouting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to calculate route via Valhalla'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRouteBottomSheet(ValhallaRouteModel route) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Valhalla Route',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRouteChip(Icons.straighten, route.distanceFormatted),
                const SizedBox(width: 10),
                _buildRouteChip(Icons.access_time_rounded, route.durationFormatted),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Turn-by-Turn Directions:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...route.maneuvers.map(
              (m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.turn_right_rounded, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devName = _device?.name ?? 'Device';
    final lat = _currentLocation?.latitude ?? 16.2356;
    final lon = _currentLocation?.longitude ?? 80.0498;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$devName Location'),
        actions: [
          IconButton(
            tooltip: 'Simulate Live GPS Ping',
            icon: const Icon(Icons.satellite_alt_rounded),
            onPressed: () {
              final newLat = (_currentLocation?.latitude ?? 16.2356) + 0.001;
              final newLon = (_currentLocation?.longitude ?? 80.0498) + 0.001;
              _webSocketService.sendLocationPing(
                latitude: newLat,
                longitude: newLon,
                accuracy: 5.0,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Simulated live GPS ping broadcast via WebSocket'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Location',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDeviceAndLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // MapLibre Map View
                _isTest
                    ? Container(
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: Text('MapLibre GL Map View (Test Mode)'),
                        ),
                      )
                    : MapLibreMap(
                        styleString: ApiConstants.mapLibreStyleUrl,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lon),
                          zoom: 14.5,
                        ),
                        onMapCreated: _onMapCreated,
                        myLocationEnabled: true,
                        myLocationTrackingMode: MyLocationTrackingMode.none,
                        compassEnabled: true,
                      ),

                // Floating Info & Operations Card
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Card(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.place_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      devName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Updated: ${_currentLocation != null ? _currentLocation!.timestamp.toLocal().toString().split('.').first : "Just now"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildWebSocketStatusBadge(),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.border),

                          // Coordinates row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Latitude', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${lat.toStringAsFixed(6)}°',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Longitude', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${lon.toStringAsFixed(6)}°',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Accuracy', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '±${(_currentLocation?.accuracy ?? 10.0).toStringAsFixed(1)}m',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_route != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Distance: ${_route!.distanceFormatted}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'ETA: ${_route!.durationFormatted}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Valhalla Directions Button
                          CustomButton(
                            text: 'Route with Valhalla',
                            icon: Icons.directions_outlined,
                            isLoading: _isRouting,
                            onPressed: _fetchValhallaRoute,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWebSocketStatusBadge() {
    Color color;
    String text;

    switch (_wsStatus) {
      case WebSocketConnectionStatus.connected:
        color = AppColors.online;
        text = 'Live WebSocket';
        break;
      case WebSocketConnectionStatus.connecting:
        color = AppColors.warning;
        text = 'Connecting...';
        break;
      case WebSocketConnectionStatus.reconnecting:
        color = AppColors.warning;
        text = 'Reconnecting...';
        break;
      case WebSocketConnectionStatus.error:
        color = AppColors.error;
        text = 'WS Error';
        break;
      case WebSocketConnectionStatus.disconnected:
        color = AppColors.offline;
        text = 'Disconnected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
