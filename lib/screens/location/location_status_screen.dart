import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/api_exception.dart';
import '../../models/location_model.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_button.dart';

class LocationStatusScreen extends StatefulWidget {
  const LocationStatusScreen({super.key});

  @override
  State<LocationStatusScreen> createState() => _LocationStatusScreenState();
}

class _LocationStatusScreenState extends State<LocationStatusScreen> {
  final LocationService _locationService = LocationService();

  LocationModel? _currentLocation;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentLocation = loc;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not acquire GPS position. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GPS & Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh GPS',
            onPressed: _isLoading ? null : _fetchLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Device GPS Sensor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'High-accuracy real-time positioning',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error banner if any
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, color: AppColors.error, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Coordinates Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Position',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_currentLocation != null ? AppColors.online : AppColors.offline)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentLocation != null ? AppColors.online : AppColors.offline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _currentLocation != null ? 'Acquired' : 'Searching',
                                  style: TextStyle(
                                    color: _currentLocation != null ? AppColors.online : AppColors.offline,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_currentLocation != null) ...[
                        _buildMetricRow(
                          icon: Icons.explore_outlined,
                          label: 'Latitude',
                          value: '${_currentLocation!.latitude.toStringAsFixed(6)}°',
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        _buildMetricRow(
                          icon: Icons.navigation_outlined,
                          label: 'Longitude',
                          value: '${_currentLocation!.longitude.toStringAsFixed(6)}°',
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        _buildMetricRow(
                          icon: Icons.adjust_rounded,
                          label: 'Accuracy',
                          value: '±${_currentLocation!.accuracy.toStringAsFixed(1)} m',
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        _buildMetricRow(
                          icon: Icons.access_time_rounded,
                          label: 'Timestamp',
                          value: _currentLocation!.timestamp.toLocal().toString().split('.').first,
                        ),
                      ] else ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Tap below to request permission and acquire GPS coordinates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action button
              CustomButton(
                text: 'Acquire Current Location',
                isLoading: _isLoading,
                icon: Icons.my_location_rounded,
                onPressed: _fetchLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
