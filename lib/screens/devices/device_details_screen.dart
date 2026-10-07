import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final DeviceModel? initialDevice;
  final int? deviceId;

  const DeviceDetailsScreen({
    super.key,
    this.initialDevice,
    this.deviceId,
  });

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final DeviceService _deviceService = DeviceService();

  DeviceModel? _device;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _device = widget.initialDevice;
    if (_device != null) {
      _isLoading = false;
    }
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final id = widget.deviceId ?? widget.initialDevice?.id;
    if (id == null) return;

    try {
      final freshDevice = await _deviceService.getDeviceById(id);
      if (!mounted) return;
      setState(() {
        _device = freshDevice;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteDevice() async {
    if (_device == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text('Are you sure you want to delete "${_device!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deviceService.deleteDevice(_device!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_device!.name} deleted successfully'),
          backgroundColor: AppColors.online,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _device ?? widget.initialDevice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(device?.name ?? 'Device Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDevice,
          ),
        ],
      ),
      body: _isLoading && device == null
          ? const Center(child: CircularProgressIndicator())
          : device == null
              ? const Center(child: Text('Device not found'))
              : RefreshIndicator(
                  onRefresh: _loadDevice,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Device Card
                        _buildHeaderCard(device),
                        const SizedBox(height: 16),

                        // Battery & Status Grid
                        _buildBatteryCard(device),
                        const SizedBox(height: 12),
                        _buildStatusCard(device),
                        const SizedBox(height: 20),

                        // Device Actions Section
                        const Text(
                          'Device Operations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.map_outlined,
                          title: 'Locate on Map',
                          subtitle: 'View live GPS position on interactive map',
                          color: AppColors.primary,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Live map tracking for ${device.name} (Ready in Phase 6)'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        _buildActionTile(
                          icon: Icons.volume_up_outlined,
                          title: 'Play Sound',
                          subtitle: 'Ring device at maximum volume to locate nearby',
                          color: AppColors.secondary,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ringing ${device.name}... (Ready in Phase 10)'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        _buildActionTile(
                          icon: Icons.lock_clock_outlined,
                          title: 'Lost Mode',
                          subtitle: 'Lock screen and display return contact info',
                          color: AppColors.warning,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lost mode toggle for ${device.name} (Ready in Phase 10)'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Delete Device Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                          label: const Text(
                            'Remove This Device',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _handleDeleteDevice,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard(DeviceModel device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                device.deviceType.toLowerCase() == 'android'
                    ? Icons.phone_android_rounded
                    : Icons.devices_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          device.deviceType,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (device.isOnline ? AppColors.online : AppColors.offline).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: device.isOnline ? AppColors.online : AppColors.offline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              device.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: device.isOnline ? AppColors.online : AppColors.offline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard(DeviceModel device) {
    Color batteryColor;
    if (device.batteryLevel > 50) {
      batteryColor = AppColors.online;
    } else if (device.batteryLevel > 20) {
      batteryColor = AppColors.warning;
    } else {
      batteryColor = AppColors.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.battery_charging_full_rounded, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Battery Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${device.batteryLevel}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: batteryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: device.batteryLevel / 100,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(DeviceModel device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Device ID', '#${device.id}'),
            const Divider(color: AppColors.border, height: 20),
            _buildDetailRow('Last Seen', device.formattedLastSeen),
            if (device.lastSeen != null) ...[
              const Divider(color: AppColors.border, height: 20),
              _buildDetailRow(
                'Timestamp',
                device.lastSeen!.toLocal().toString().split('.').first,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
      ),
    );
  }
}
