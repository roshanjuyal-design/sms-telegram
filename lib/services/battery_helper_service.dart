import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

class BatteryHelperService {
  static const MethodChannel _channel = MethodChannel('com.example.sms_to_telegram/sms');

  static const String keyHeartbeatEnabled = 'heartbeat_enabled';
  static const String keyHeartbeatIntervalHours = 'heartbeat_interval_hours';
  static const String keyHeartbeatIntervalMinutes = 'heartbeat_interval_minutes';
  static const String keyLastHeartbeatTime = 'heartbeat_last_timestamp';

  static Timer? _heartbeatTimer;

  /// Check if Battery Optimization is ignored (Unrestricted)
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request system dialog to ignore battery optimizations
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Error requesting ignore battery optimization: $e');
    }
  }

  /// Open manufacturer-specific Auto-Start / Background manager settings
  static Future<bool> openAutoStartSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening auto start settings: $e');
      return false;
    }
  }

  /// Open standard Android App Info page
  static Future<void> openAppDetails() async {
    try {
      await _channel.invokeMethod('openAppDetails');
    } catch (e) {
      debugPrint('Error opening app details: $e');
    }
  }

  /// Get manufacturer, model, and Android SDK
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic>? info =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo');
      if (info != null) {
        return Map<String, dynamic>.from(info);
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    return {
      'manufacturer': 'Android Device',
      'model': 'Generic',
      'brand': 'Android',
      'sdkVersion': 0,
    };
  }

  /// Get live battery level and charging status
  static Future<Map<String, dynamic>> getBatteryInfo() async {
    try {
      final Map<dynamic, dynamic>? info =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getBatteryInfo');
      if (info != null) {
        return Map<String, dynamic>.from(info);
      }
    } catch (e) {
      debugPrint('Error getting battery info: $e');
    }
    return {
      'batteryLevel': -1,
      'isCharging': false,
    };
  }

  /// Get heartbeat settings
  static Future<bool> isHeartbeatEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyHeartbeatEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<int> getHeartbeatIntervalMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mins = prefs.getInt(keyHeartbeatIntervalMinutes);
      if (mins != null) return mins;
      final hours = prefs.getInt(keyHeartbeatIntervalHours);
      if (hours != null) return hours * 60;
      return 30;
    } catch (_) {
      return 30;
    }
  }

  static Future<int> getHeartbeatIntervalHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(keyHeartbeatIntervalHours) ?? 12;
    } catch (_) {
      return 12;
    }
  }

  static Future<void> setHeartbeatEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHeartbeatEnabled, enabled);
      if (enabled) {
        startHeartbeatTimer();
      } else {
        stopHeartbeatTimer();
      }
    } catch (e) {
      debugPrint('Error saving heartbeat setting: $e');
    }
  }

  static Future<void> setHeartbeatIntervalMinutes(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyHeartbeatIntervalMinutes, minutes);
      await prefs.setInt(keyHeartbeatIntervalHours, (minutes / 60).ceil());
      final isEnabled = await isHeartbeatEnabled();
      if (isEnabled) {
        startHeartbeatTimer();
      }
    } catch (e) {
      debugPrint('Error saving heartbeat interval: $e');
    }
  }

  static Future<void> setHeartbeatIntervalHours(int hours) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyHeartbeatIntervalHours, hours);
      await prefs.setInt(keyHeartbeatIntervalMinutes, hours * 60);
      final isEnabled = await isHeartbeatEnabled();
      if (isEnabled) {
        startHeartbeatTimer();
      }
    } catch (e) {
      debugPrint('Error saving heartbeat interval: $e');
    }
  }

  /// Send Heartbeat Watchdog Ping to all active Telegram agents
  static Future<Map<String, int>> sendHeartbeatPing({bool isManualTest = false}) async {
    final devInfo = await getDeviceInfo();
    final battInfo = await getBatteryInfo();

    final String manufacturer = (devInfo['manufacturer'] ?? '').toString();
    final String model = (devInfo['model'] ?? '').toString();
    final int batteryLevel = battInfo['batteryLevel'] is int ? battInfo['batteryLevel'] as int : -1;
    final bool isCharging = battInfo['isCharging'] as bool? ?? false;

    final String batteryText = batteryLevel >= 0
        ? '$batteryLevel% ${isCharging ? '⚡ (Charging)' : '🔋'}'
        : 'Unknown';

    final String title = isManualTest
        ? '💓 *InyaTech Heartbeat Test Ping*'
        : '💓 *InyaTech 24/7 System Heartbeat*';

    final StringBuffer sb = StringBuffer('$title\n\n');
    sb.writeln('🟢 *Status:* System Active & Monitoring 24/7');
    sb.writeln('📱 *Device:* $manufacturer $model');
    sb.writeln('🔋 *Battery:* $batteryText');
    sb.writeln('⏰ *Timestamp:* _${DateTime.now().toLocal().toString().split('.').first}_');
    sb.writeln('\n_All SMS forwarder services are running smoothly._');

    final result = await SettingsService.sendBroadcastMessage(message: sb.toString());

    // Record last sent timestamp
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLastHeartbeatTime, DateTime.now().toIso8601String());
    } catch (_) {}

    return result;
  }

  /// Start background heartbeat timer
  static Future<void> startHeartbeatTimer() async {
    stopHeartbeatTimer();
    final bool isEnabled = await isHeartbeatEnabled();
    if (!isEnabled) return;

    final int minutes = await getHeartbeatIntervalMinutes();
    final duration = Duration(minutes: minutes > 0 ? minutes : 30);

    _heartbeatTimer = Timer.periodic(duration, (timer) async {
      final enabled = await isHeartbeatEnabled();
      if (enabled) {
        await sendHeartbeatPing(isManualTest: false);
      }
    });
  }

  static void stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
