import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../models/tracking_mode_model.dart';
import '../../services/background_location_service.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_button.dart';

class BackgroundTrackingScreen extends StatefulWidget {
  final DeviceModel? device;
  final int? deviceId;

  const BackgroundTrackingScreen({
    super.key,
    this.device,
    this.deviceId,
  });

  @override
  State<BackgroundTrackingScreen> createState() => _BackgroundTrackingScreenState();
}

class _BackgroundTrackingScreenState extends State<BackgroundTrackingScreen> {
  final BackgroundLocationService _bgService = BackgroundLocationService();
  final LocationService _locationService = LocationService();

  bool _isTracking = false;
  TrackingMode _selectedMode = TrackingMode.balanced;
  bool _hasBackgroundPermission = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _isTracking = _bgService.isTracking;
    _selectedMode = _bgService.currentMode;
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await _locationService.hasBackgroundPermission();
    if (!mounted) return;
    setState(() => _hasBackgroundPermission = granted);
  }

  Future<void> _requestBackgroundPermission() async {
    await _locationService.requestBackgroundPermission();
    await _checkPermissions();
  }

  Future<void> _toggleTracking(bool value) async {
    final devId = widget.deviceId ?? widget.device?.id ?? 101;

    if (value) {
      await _bgService.startTracking(
        deviceId: devId,
        mode: _selectedMode,
      );
    } else {
      await _bgService.stopTracking();
    }

    if (!mounted) return;
    setState(() {
      _isTracking = _bgService.isTracking;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Background protection enabled (${_selectedMode.title})'
              : 'Background protection disabled',
        ),
        backgroundColor: value ? AppColors.online : AppColors.offline,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeMode(TrackingMode mode) async {
    setState(() => _selectedMode = mode);
    await _bgService.setTrackingMode(mode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${mode.title} tracking profile'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _forceSyncNow() async {
    setState(() => _isSyncing = true);
    final loc = await _bgService.syncNow();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (loc != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS ping sent: (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})'),
          backgroundColor: AppColors.online,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to transmit GPS location to server.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final devName = widget.device?.name ?? 'Device';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Background Tracking'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Master Protection Card
              _buildMasterSwitchCard(devName),
              const SizedBox(height: 16),

              // Background Permission Warning (if needed)
              if (!_hasBackgroundPermission) ...[
                _buildPermissionAlertCard(),
                const SizedBox(height: 16),
              ],

              // Tracking Profiles Section
              const Text(
                'Battery & Tracking Profiles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...TrackingMode.values.map(_buildModeSelectionCard),
              const SizedBox(height: 20),

              // Live Statistics Card
              _buildStatisticsCard(),
              const SizedBox(height: 20),

              // Foreground Notification Preview
              _buildNotificationPreviewCard(),
              const SizedBox(height: 24),

              // Manual Ping Sync Button
              CustomButton(
                text: 'Force GPS Sync Now',
                icon: Icons.sync_rounded,
                isLoading: _isSyncing,
                isOutlined: true,
                onPressed: _forceSyncNow,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterSwitchCard(String devName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isTracking ? AppColors.online.withValues(alpha: 0.5) : AppColors.border,
          width: _isTracking ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (_isTracking)
            BoxShadow(
              color: AppColors.online.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (_isTracking ? AppColors.online : AppColors.offline).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isTracking ? Icons.security_rounded : Icons.security_outlined,
              color: _isTracking ? AppColors.online : AppColors.offline,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTracking ? 'Protection Active' : 'Protection Disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isTracking ? AppColors.online : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isTracking
                      ? 'Reporting $devName GPS location in the background'
                      : 'Enable to track $devName even when the app is closed',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isTracking,
            activeTrackColor: AppColors.online,
            activeThumbColor: Colors.white,
            onChanged: _toggleTracking,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Background Permission Required',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'To keep this device protected when TraceUp is minimized or the screen is locked, select "Allow all the time" in location settings.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Grant Background Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _requestBackgroundPermission,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionCard(TrackingMode mode) {
    final isSelected = _selectedMode == mode;

    IconData modeIcon;
    Color modeColor;

    switch (mode) {
      case TrackingMode.balanced:
        modeIcon = Icons.balance_rounded;
        modeColor = AppColors.primary;
        break;
      case TrackingMode.active:
        modeIcon = Icons.flash_on_rounded;
        modeColor = AppColors.warning;
        break;
      case TrackingMode.batterySaver:
        modeIcon = Icons.battery_saver_rounded;
        modeColor = AppColors.online;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? modeColor : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _changeMode(mode),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(modeIcon, color: modeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mode.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? modeColor : AppColors.textPrimary,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: modeColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final lastTime = _bgService.lastPingTime;
    final timeStr = lastTime != null
        ? '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}'
        : 'None yet';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracking Metrics',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pings Sent', '${_bgService.pingsSentCount}', Icons.cloud_upload_outlined),
              Container(width: 1, height: 32, color: AppColors.border),
              _buildStatItem('Last Sync', timeStr, Icons.access_time_rounded),
              Container(width: 1, height: 32, color: AppColors.border),
              _buildStatItem('Interval', '${_bgService.intervalMinutes}m', Icons.timer_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNotificationPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Android Foreground Notification Preview',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: const Row(
              children: [
                Icon(Icons.location_searching_rounded, color: AppColors.primary, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TraceUp Protection Active',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Securing and tracking your device location in background',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
