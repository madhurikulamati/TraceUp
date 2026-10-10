import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/map_constants.dart';
import '../../models/device_model.dart';
import '../../models/location_model.dart';
import '../../models/place_search_result.dart';
import '../../models/valhalla_route_model.dart';
import '../../models/websocket_event_model.dart';
import '../../services/device_service.dart';
import '../../services/geocoding_service.dart';
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
  final GeocodingService _geocodingService = GeocodingService();

  MapLibreMapController? _mapController;
  DeviceModel? _device;
  LocationModel? _currentLocation;
  LocationModel? _userLocation;
  ValhallaRouteModel? _route;

  String _currentStyleUrl = MapConstants.defaultStyleUrl;
  bool _isLoading = true;
  bool _isRouting = false;
  bool _isLocatingUser = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PlaceSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _searchDebounceTimer;

  // Tracked Device Marker & Accuracy Circle (Emerald/Green Theme)
  Circle? _deviceAccuracyCircle;
  Symbol? _deviceSymbol;

  // My Current Phone Marker & Accuracy Circle (Navigation Blue Theme)
  Circle? _userAccuracyCircle;
  Circle? _userLocationDot;
  Symbol? _userSymbol;

  // Temporary Destination / Search Pin
  Symbol? _searchPinSymbol;

  WebSocketConnectionStatus _wsStatus = WebSocketConnectionStatus.disconnected;
  StreamSubscription<WebSocketConnectionStatus>? _wsStatusSubscription;
  StreamSubscription<LocationModel>? _wsLocationSubscription;

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _fetchDeviceAndLocation();
    _fetchUserLocation();
    _initWebSocket();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      // Smoothly update device marker without rebuilding the entire map or hijacking camera
      _updateDeviceMarker();
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

      _updateDeviceMarker();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LocationModel(
          deviceId: id,
          latitude: MapConstants.defaultLatitude,
          longitude: MapConstants.defaultLongitude,
          accuracy: 10.5,
          timestamp: DateTime.now(),
        );
        _isLoading = false;
      });
      _updateDeviceMarker();
    }
  }

  Future<void> _fetchUserLocation({bool animateCamera = false}) async {
    setState(() => _isLocatingUser = true);
    try {
      final userLoc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = userLoc;
        _isLocatingUser = false;
      });

      _updateUserMarker();

      if (animateCamera && _mapController != null && !_isTest) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(userLoc.latitude, userLoc.longitude),
              zoom: MapConstants.userFocusZoom,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLocatingUser = false);
      if (animateCamera) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine current GPS position. Check permissions.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _updateDeviceMarker();
    _updateUserMarker();
  }

  void _onStyleLoaded() {
    _deviceAccuracyCircle = null;
    _deviceSymbol = null;
    _userAccuracyCircle = null;
    _userLocationDot = null;
    _userSymbol = null;
    _searchPinSymbol = null;
    _updateDeviceMarker();
    _updateUserMarker();
  }

  /// Updates the tracked device marker (emerald pin with device name and distinct accuracy ring)
  Future<void> _updateDeviceMarker() async {
    if (_mapController == null || _currentLocation == null || _isTest) return;

    try {
      final devTarget = LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
      final devName = _device?.name ?? 'Device';
      final accuracy = _currentLocation!.accuracy > 0 ? _currentLocation!.accuracy : 12.0;

      // 1. Device accuracy circle (Soft emerald tint)
      if (_deviceAccuracyCircle != null) {
        await _mapController!.updateCircle(
          _deviceAccuracyCircle!,
          CircleOptions(
            geometry: devTarget,
            circleRadius: accuracy,
          ),
        );
      } else {
        _deviceAccuracyCircle = await _mapController!.addCircle(
          CircleOptions(
            geometry: devTarget,
            circleRadius: accuracy,
            circleColor: '#10B981',
            circleOpacity: 0.12,
            circleStrokeColor: '#059669',
            circleStrokeWidth: 1.5,
            circleStrokeOpacity: 0.5,
          ),
        );
      }

      // 2. Tracked device symbol marker
      if (_deviceSymbol != null) {
        await _mapController!.updateSymbol(
          _deviceSymbol!,
          SymbolOptions(
            geometry: devTarget,
            textField: devName,
          ),
        );
      } else {
        _deviceSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: devTarget,
            iconImage: 'marker-15',
            iconSize: 2.1,
            textField: devName,
            textOffset: const Offset(0, 1.2),
            textColor: '#065F46',
            textSize: 13,
            textHaloColor: '#FFFFFF',
            textHaloWidth: 2.0,
          ),
        );
      }
    } catch (_) {}
  }

  /// Updates my current phone marker (vivid navigation blue puck with GPS accuracy circle)
  Future<void> _updateUserMarker() async {
    if (_mapController == null || _userLocation == null || _isTest) return;

    try {
      final userTarget = LatLng(_userLocation!.latitude, _userLocation!.longitude);
      final accuracy = _userLocation!.accuracy > 0 ? _userLocation!.accuracy : 15.0;

      // 1. User GPS accuracy circle (Navigation blue tint)
      if (_userAccuracyCircle != null) {
        await _mapController!.updateCircle(
          _userAccuracyCircle!,
          CircleOptions(
            geometry: userTarget,
            circleRadius: accuracy,
          ),
        );
      } else {
        _userAccuracyCircle = await _mapController!.addCircle(
          CircleOptions(
            geometry: userTarget,
            circleRadius: accuracy,
            circleColor: '#3B82F6',
            circleOpacity: 0.12,
            circleStrokeColor: '#2563EB',
            circleStrokeWidth: 1.5,
            circleStrokeOpacity: 0.6,
          ),
        );
      }

      // 2. User Center GPS Puck (Vibrant navigation blue dot with crisp white border)
      if (_userLocationDot != null) {
        await _mapController!.updateCircle(
          _userLocationDot!,
          CircleOptions(geometry: userTarget),
        );
      } else {
        _userLocationDot = await _mapController!.addCircle(
          CircleOptions(
            geometry: userTarget,
            circleRadius: 7.5,
            circleColor: '#2563EB',
            circleOpacity: 1.0,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2.5,
            circleStrokeOpacity: 1.0,
          ),
        );
      }

      // 3. User label
      if (_userSymbol != null) {
        await _mapController!.updateSymbol(
          _userSymbol!,
          SymbolOptions(geometry: userTarget),
        );
      } else {
        _userSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: userTarget,
            textField: 'My Location',
            textOffset: const Offset(0, 1.2),
            textColor: '#1E40AF',
            textSize: 11,
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.5,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _animateToDevice() async {
    if (_mapController == null || _currentLocation == null || _isTest) return;
    final target = LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: MapConstants.deviceFocusZoom),
      ),
    );
  }

  Future<void> _animateToUser() async {
    if (_mapController == null || _isTest) return;
    if (_userLocation != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_userLocation!.latitude, _userLocation!.longitude),
            zoom: MapConstants.userFocusZoom,
          ),
        ),
      );
    }
    _fetchUserLocation(animateCamera: _userLocation == null);
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await _geocodingService.searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSearchResult(PlaceSearchResult place) async {
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchResults = false;
      _searchController.text = place.name;
    });

    if (_mapController != null && !_isTest) {
      final target = LatLng(place.latitude, place.longitude);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16.0),
        ),
      );

      // Place destination pin
      try {
        if (_searchPinSymbol != null) {
          await _mapController!.removeSymbol(_searchPinSymbol!);
        }
        _searchPinSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: target,
            iconImage: 'marker-15',
            iconSize: 2.0,
            textField: place.name,
            textOffset: const Offset(0, 1.2),
            textColor: '#047857',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 2.0,
          ),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Focused on: ${place.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showStyleSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.layers_rounded, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Map Styles & Layers',
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
              const SizedBox(height: 8),
              const Text(
                'Vector tiles provide detailed building footprints, road hierarchy and street labels.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...MapStyleOption.options.map((option) {
                final isSelected = _currentStyleUrl == option.styleUrl;
                return Material(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textLight,
                    ),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      option.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (_currentStyleUrl != option.styleUrl) {
                        setState(() {
                          _currentStyleUrl = option.styleUrl;
                        });
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchValhallaRoute() async {
    if (_currentLocation == null) return;

    setState(() => _isRouting = true);

    try {
      final userLoc = _userLocation ?? await _locationService.getCurrentLocation();

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

  Widget _buildCompactMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final devName = _device?.name ?? 'Device';
    final lat = _currentLocation?.latitude ?? MapConstants.defaultLatitude;
    final lon = _currentLocation?.longitude ?? MapConstants.defaultLongitude;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$devName Location'),
        actions: [
          IconButton(
            tooltip: 'Simulate Live GPS Ping',
            icon: const Icon(Icons.satellite_alt_rounded),
            onPressed: () {
              final newLat = (_currentLocation?.latitude ?? MapConstants.defaultLatitude) + 0.001;
              final newLon = (_currentLocation?.longitude ?? MapConstants.defaultLongitude) + 0.001;
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
            onPressed: () {
              _fetchDeviceAndLocation();
              _fetchUserLocation();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Vector Map View (MapLibre GL)
                Positioned.fill(
                  child: _isTest
                      ? Container(
                          color: AppColors.surfaceVariant,
                          child: const Center(
                            child: Text('MapLibre GL Map View (Test Mode)'),
                          ),
                        )
                      : MapLibreMap(
                          key: ValueKey(_currentStyleUrl),
                          styleString: _currentStyleUrl,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(lat, lon),
                            zoom: MapConstants.defaultZoom,
                          ),
                          onMapCreated: _onMapCreated,
                          onStyleLoadedCallback: _onStyleLoaded,
                          myLocationEnabled: false, // We render our custom high-fidelity navigation GPS puck
                          compassEnabled: true,
                          trackCameraPosition: true,
                          rotateGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                          doubleClickZoomEnabled: true,
                        ),
                ),

                // 2. Top Floating Search Bar (Modern navigation capsule style)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search places, streets, landmarks...',
                              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchResults = [];
                                              _showSearchResults = false;
                                            });
                                          },
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),

                        // Search Results Dropdown List
                        if (_showSearchResults && _searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                                itemBuilder: (context, index) {
                                  final place = _searchResults[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                                    title: Text(
                                      place.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      place.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    onTap: () => _selectSearchResult(place),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 3. Floating Control Action Buttons (Clean right-side stack)
                Positioned(
                  right: 16,
                  bottom: 175,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Map Layer / Style Switcher Button
                      FloatingActionButton.small(
                        heroTag: 'map_style_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 3,
                        tooltip: 'Map Layers',
                        onPressed: _showStyleSelectorSheet,
                        child: const Icon(Icons.layers_rounded, size: 20),
                      ),
                      const SizedBox(height: 8),

                      // Focus Tracked Device Button
                      FloatingActionButton.small(
                        heroTag: 'focus_device_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF059669),
                        elevation: 3,
                        tooltip: 'Focus Device',
                        onPressed: _animateToDevice,
                        child: const Icon(Icons.phone_android_rounded, size: 20),
                      ),
                      const SizedBox(height: 8),

                      // My Location Floating Button (Centers to user's real GPS position)
                      FloatingActionButton(
                        heroTag: 'my_location_btn',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        tooltip: 'My Location',
                        onPressed: _animateToUser,
                        child: _isLocatingUser
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                ),

                // 4. Compact Device Information & Operations Card (Non-obstructive)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top info row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    devName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Updated: ${_currentLocation != null ? _currentLocation!.timestamp.toLocal().toString().split('.').first : "Just now"}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            _buildWebSocketStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Metrics row (Latitude, Longitude, Accuracy)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCompactMetric('Latitude', '${lat.toStringAsFixed(4)}°'),
                            _buildCompactMetric('Longitude', '${lon.toStringAsFixed(4)}°'),
                            _buildCompactMetric('Accuracy', '±${(_currentLocation?.accuracy ?? 10.0).toStringAsFixed(1)}m'),
                            if (_route != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_route!.distanceFormatted} • ${_route!.durationFormatted}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Compact Valhalla Routing Button
                        SizedBox(
                          height: 38,
                          child: CustomButton(
                            text: 'Route with Valhalla',
                            icon: Icons.directions_outlined,
                            isLoading: _isRouting,
                            onPressed: _fetchValhallaRoute,
                          ),
                        ),
                      ],
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
