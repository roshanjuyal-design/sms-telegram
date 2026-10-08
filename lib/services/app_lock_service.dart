import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const String keyLockEnabled = 'app_lock_enabled';
  static const String keyLockPin = 'app_lock_pin';
  static const String keyBiometricsEnabled = 'app_lock_biometrics_enabled';

  static const String defaultPin = '5440';
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if PIN / Passcode lock is enabled (Default: true)
  static Future<bool> isLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyLockEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggle PIN lock
  static Future<void> setLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyLockEnabled, enabled);
    } catch (e) {
      debugPrint('Error saving lock enabled: $e');
    }
  }

  /// Get current 4-digit PIN (Default: '5440')
  static Future<String> getPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyLockPin) ?? defaultPin;
    } catch (_) {
      return defaultPin;
    }
  }

  /// Set new 4-digit PIN
  static Future<bool> setPin(String newPin) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(keyLockPin, newPin);
    } catch (e) {
      debugPrint('Error setting PIN: $e');
      return false;
    }
  }

  /// Verify entered PIN against stored PIN
  static Future<bool> verifyPin(String enteredPin) async {
    final currentPin = await getPin();
    return enteredPin == currentPin;
  }

  /// Check if Biometrics unlock is enabled (Default: true)
  static Future<bool> isBiometricsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyBiometricsEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggle Biometrics unlock
  static Future<void> setBiometricsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyBiometricsEnabled, enabled);
    } catch (e) {
      debugPrint('Error saving biometrics enabled: $e');
    }
  }

  /// Check if device hardware supports biometrics
  static Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  /// Prompt user for Fingerprint / Face ID authentication
  static Future<bool> authenticateBiometrics() async {
    try {
      final canUse = await canUseBiometrics();
      if (!canUse) return false;

      return await _auth.authenticate(
        localizedReason: 'Unlock InyaTech Merchant Terminal',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected biometric auth error: $e');
      return false;
    }
  }
}
