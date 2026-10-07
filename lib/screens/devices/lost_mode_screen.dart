import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/api_exception.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class LostModeScreen extends StatefulWidget {
  final DeviceModel? device;
  final int? deviceId;

  const LostModeScreen({
    super.key,
    this.device,
    this.deviceId,
  });

  @override
  State<LostModeScreen> createState() => _LostModeScreenState();
}

class _LostModeScreenState extends State<LostModeScreen> {
  final DeviceService _deviceService = DeviceService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _phoneController;
  late TextEditingController _messageController;

  DeviceModel? _device;
  bool _isLost = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocking = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _phoneController = TextEditingController(text: widget.device?.lostPhoneNumber ?? '');
    _messageController = TextEditingController(
      text: widget.device?.lostMessage ?? 'This device is lost. Please call me if found!',
    );
    _loadLostMode();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadLostMode() async {
    final devId = widget.deviceId ?? widget.device?.id ?? 101;

    try {
      final dev = widget.device ?? await _deviceService.getDeviceById(devId);
      final lostMode = await _deviceService.getLostMode(devId);

      if (!mounted) return;
      setState(() {
        _device = dev;
        _isLost = lostMode.isLost || dev.isLost;
        if (lostMode.phoneNumber != null && lostMode.phoneNumber!.isNotEmpty) {
          _phoneController.text = lostMode.phoneNumber!;
        }
        if (lostMode.message != null && lostMode.message!.isNotEmpty) {
          _messageController.text = lostMode.message!;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLostMode(bool enable) async {
    if (enable && !_formKey.currentState!.validate()) {
      return;
    }

    final devId = widget.deviceId ?? _device?.id ?? 101;
    setState(() => _isSaving = true);

    try {
      final updated = await _deviceService.setLostMode(
        devId,
        isLost: enable,
        phoneNumber: _phoneController.text.trim(),
        message: _messageController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isLost = updated.isLost;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? 'Lost Mode enabled for ${_device?.name ?? "device"}'
                : 'Lost Mode deactivated',
          ),
          backgroundColor: enable ? AppColors.warning : AppColors.online,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update Lost Mode'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleRemoteLock() async {
    final devId = widget.deviceId ?? _device?.id ?? 101;
    setState(() => _isLocking = true);

    try {
      await _deviceService.lockDevice(
        devId,
        lockMessage: _messageController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLocking = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Device Locked'),
            ],
          ),
          content: Text('A remote lock command was dispatched to ${_device?.name ?? "your device"}. The screen is now secured with your return message.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLocking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to lock device remotely'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final devName = _device?.name ?? 'Device';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$devName Lost Mode'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Lost Mode Status Banner
                      _buildStatusBanner(devName),
                      const SizedBox(height: 16),

                      // Return Contact Configuration Form
                      _buildConfigurationCard(),
                      const SizedBox(height: 20),

                      // Live Lock Screen Preview
                      _buildLockScreenPreview(),
                      const SizedBox(height: 24),

                      // Action Buttons
                      if (!_isLost)
                        CustomButton(
                          text: 'Activate Lost Mode',
                          icon: Icons.lock_clock_rounded,
                          isLoading: _isSaving,
                          onPressed: () => _saveLostMode(true),
                        )
                      else ...[
                        CustomButton(
                          text: 'Deactivate Lost Mode',
                          icon: Icons.lock_open_rounded,
                          isLoading: _isSaving,
                          isOutlined: true,
                          onPressed: () => _saveLostMode(false),
                        ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: 'Dispatch Immediate Screen Lock',
                          icon: Icons.screen_lock_portrait_rounded,
                          isLoading: _isLocking,
                          onPressed: _handleRemoteLock,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBanner(String devName) {
    final color = _isLost ? AppColors.warning : AppColors.online;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isLost ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLost ? 'LOST MODE ACTIVE' : 'Device Protected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isLost
                      ? '$devName is marked lost. Screen displays return info.'
                      : 'Lost Mode is currently turned off for $devName.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
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
            'Recovery Contact Information',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Provide a contact phone number and custom message that will appear on the device lock screen.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Contact Phone Number',
            hint: 'e.g. +91 98765 43210',
            prefixIcon: Icons.phone_outlined,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter a contact number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Lock Screen Recovery Message',
            hint: 'Message for anyone who finds this device',
            prefixIcon: Icons.chat_bubble_outline_rounded,
            controller: _messageController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter a recovery message';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLockScreenPreview() {
    final phone = _phoneController.text.trim().isEmpty ? '9876543210' : _phoneController.text.trim();
    final message = _messageController.text.trim().isEmpty
        ? 'This device is lost. Please contact the owner!'
        : _messageController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lock Screen Display Preview',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Dark slate lock screen
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.lock_person_rounded, color: AppColors.warning, size: 36),
              const SizedBox(height: 12),
              const Text(
                'THIS DEVICE IS LOST',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.online,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Call $phone',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
