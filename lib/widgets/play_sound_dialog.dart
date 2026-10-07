import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/device_service.dart';
import 'custom_button.dart';

class PlaySoundDialog extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const PlaySoundDialog({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  static Future<void> show(BuildContext context, {required int deviceId, required String deviceName}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PlaySoundDialog(deviceId: deviceId, deviceName: deviceName),
    );
  }

  @override
  State<PlaySoundDialog> createState() => _PlaySoundDialogState();
}

class _PlaySoundDialogState extends State<PlaySoundDialog> with SingleTickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minutes max ringing
  bool _isStopping = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (!_isTest) {
      _animController.repeat(reverse: true);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          _stopSound();
        }
      });
    }

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Call play sound API
    _deviceService.playSound(widget.deviceId);
  }

  bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void dispose() {
    _animController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _stopSound() async {
    setState(() => _isStopping = true);
    _countdownTimer?.cancel();
    _animController.stop();
    await _deviceService.stopSound(widget.deviceId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Pulsing Bell
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ringing Title
            Text(
              'Ringing ${widget.deviceName}...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Volume notification banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_rounded, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Playing at maximum volume (overrides silent)',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Countdown timer display
            Text(
              'Auto-stop in: ${_formatCountdown(_secondsRemaining)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Stop Ringing Button
            CustomButton(
              text: 'Stop Ringing',
              icon: Icons.stop_rounded,
              isLoading: _isStopping,
              backgroundColor: AppColors.error,
              onPressed: _stopSound,
            ),
          ],
        ),
      ),
    );
  }
}
