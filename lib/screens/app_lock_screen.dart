import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_lock_service.dart';
import '../theme/ios_theme.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool isChangePinMode;

  const AppLockScreen({
    super.key,
    required this.onUnlocked,
    this.isChangePinMode = false,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _errorText = '';
  bool _isShaking = false;
  bool _hasBiometrics = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _checkBiometricsAndPrompt();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricsAndPrompt() async {
    if (widget.isChangePinMode) return;

    final isBioEnabled = await AppLockService.isBiometricsEnabled();
    final canBio = await AppLockService.canUseBiometrics();

    if (mounted) {
      setState(() => _hasBiometrics = isBioEnabled && canBio);
    }

    if (isBioEnabled && canBio) {
      // Short delay for smooth UI transition before launching biometric prompt
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _triggerBiometricAuth();
      }
    }
  }

  Future<void> _triggerBiometricAuth() async {
    final success = await AppLockService.authenticateBiometrics();
    if (success && mounted) {
      HapticFeedback.lightImpact();
      widget.onUnlocked();
    }
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin += digit;
        _errorText = '';
      });

      if (_enteredPin.length == 4) {
        _verifyPin(_enteredPin);
      }
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorText = '';
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    final isValid = await AppLockService.verifyPin(pin);

    if (isValid) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        widget.onUnlocked();
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isShaking = true;
        _errorText = 'Incorrect PIN. Try again.';
      });

      _shakeController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _isShaking = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: IosColors.systemBackground,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Shield Icon
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: IosColors.systemBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: IosColors.systemBlue.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.lock_shield_fill,
                  size: 38,
                  color: IosColors.systemBlue,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Text(
                'InyaTech Security',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: IosColors.label,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle
              Text(
                widget.isChangePinMode
                    ? 'Enter current 4-digit PIN'
                    : 'Enter 4-digit Passcode to access terminal',
                style: const TextStyle(
                  fontSize: 14,
                  color: IosColors.secondaryLabel,
                ),
              ),

              const SizedBox(height: 28),

              // 4 PIN Dots with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset = _isShaking ? _shakeAnimation.value : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    final hasError = _errorText.isNotEmpty;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (hasError ? IosColors.systemRed : IosColors.systemBlue)
                            : Colors.transparent,
                        border: Border.all(
                          color: hasError
                              ? IosColors.systemRed
                              : (isFilled ? IosColors.systemBlue : IosColors.secondaryLabel.withValues(alpha: 0.6)),
                          width: 1.8,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: (hasError ? IosColors.systemRed : IosColors.systemBlue)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              // Error Text
              Container(
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  _errorText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: IosColors.systemRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // iOS Number Pad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  children: [
                    _buildDialRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildDialRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildDialRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometrics button
                        _hasBiometrics
                            ? _buildIconButton(
                                icon: CupertinoIcons.viewfinder,
                                onTap: _triggerBiometricAuth,
                              )
                            : const SizedBox(width: 72, height: 72),
                        // Number 0
                        _buildDialButton('0'),
                        // Delete button
                        _buildIconButton(
                          icon: CupertinoIcons.delete_left,
                          onTap: _onDeletePress,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDialButton(d)).toList(),
    );
  }

  Widget _buildDialButton(String digit) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: IosColors.secondaryBackground,
        border: Border.all(
          color: IosColors.separator,
          width: 0.8,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(36),
        onPressed: () => _onKeyPress(digit),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: IosColors.label,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Icon(
          icon,
          size: 26,
          color: IosColors.label,
        ),
      ),
    );
  }
}
