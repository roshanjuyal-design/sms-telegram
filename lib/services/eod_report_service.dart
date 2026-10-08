import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_log.dart';
import 'battery_helper_service.dart';
import 'settings_service.dart';
import 'transaction_history_service.dart';

class EodReportService {
  static const String keyEodEnabled = 'eod_report_enabled';
  static const String keyEodHour = 'eod_report_hour';
  static const String keyEodMinute = 'eod_report_minute';
  static const String keyEodLastSentDate = 'eod_last_sent_date';

  static const int defaultHour = 23;
  static const int defaultMinute = 59;

  static Timer? _scheduledTimer;
  static Timer? _watchdogTimer;

  /// Check if EOD Automatic Night Report is enabled (Default: true)
  static Future<bool> isEodEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyEodEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggle EOD report enabled state
  static Future<void> setEodEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyEodEnabled, enabled);
      if (enabled) {
        startScheduler();
      } else {
        stopScheduler();
      }
    } catch (e) {
      debugPrint('Error saving EOD enabled: $e');
    }
  }

  /// Get scheduled EOD Hour (0-23)
  static Future<int> getEodHour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(keyEodHour) ?? defaultHour;
    } catch (_) {
      return defaultHour;
    }
  }

  /// Get scheduled EOD Minute (0-59)
  static Future<int> getEodMinute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(keyEodMinute) ?? defaultMinute;
    } catch (_) {
      return defaultMinute;
    }
  }

  /// Set scheduled EOD Time
  static Future<void> setEodTime(int hour, int minute) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyEodHour, hour);
      await prefs.setInt(keyEodMinute, minute);
      final enabled = await isEodEnabled();
      if (enabled) {
        startScheduler();
      }
    } catch (e) {
      debugPrint('Error saving EOD time: $e');
    }
  }

  /// Get last successfully sent date string (YYYY-MM-DD)
  static Future<String?> getLastSentDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyEodLastSentDate);
    } catch (_) {
      return null;
    }
  }

  /// Construct the formatted Markdown EOD Settlement Report
  static Future<String> buildEodReportMessage({
    DateTime? targetDate,
    bool isManualTest = false,
  }) async {
    final date = targetDate ?? DateTime.now();
    final logs = await TransactionHistoryService.getLogs();

    // Filter logs for the target date
    final dayLogs = logs.where((l) =>
        l.timestamp.year == date.year &&
        l.timestamp.month == date.month &&
        l.timestamp.day == date.day).toList();

    final forwardedLogs = dayLogs.where((l) => l.status == TransactionStatus.forwarded).toList();
    final filteredLogs = dayLogs.where((l) => l.status == TransactionStatus.filtered).toList();
    final failedLogs = dayLogs.where((l) => l.status == TransactionStatus.failed).toList();

    final double totalAmount = forwardedLogs.fold(0.0, (sum, l) => sum + l.amount);
    final int count = forwardedLogs.length;

    double highestAmount = 0.0;
    for (final l in forwardedLogs) {
      if (l.amount > highestAmount) {
        highestAmount = l.amount;
      }
    }

    String firstTime = '-';
    String lastTime = '-';
    if (forwardedLogs.isNotEmpty) {
      // Sort chronologically ascending to find first and last
      final sorted = List<TransactionLog>.from(forwardedLogs)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final firstDt = sorted.first.timestamp;
      final lastDt = sorted.last.timestamp;
      firstTime = '${firstDt.hour.toString().padLeft(2, '0')}:${firstDt.minute.toString().padLeft(2, '0')}';
      lastTime = '${lastDt.hour.toString().padLeft(2, '0')}:${lastDt.minute.toString().padLeft(2, '0')}';
    }

    // Device telemetry
    final devInfo = await BatteryHelperService.getDeviceInfo();
    final battInfo = await BatteryHelperService.getBatteryInfo();
    final String manufacturer = (devInfo['manufacturer'] ?? '').toString();
    final String model = (devInfo['model'] ?? '').toString();
    final int batteryLevel = battInfo['batteryLevel'] is int ? battInfo['batteryLevel'] as int : -1;
    final bool isCharging = battInfo['isCharging'] as bool? ?? false;
    final String batteryText = batteryLevel >= 0
        ? '$batteryLevel% ${isCharging ? '⚡ (Charging)' : '🔋'}'
        : 'Unknown';

    final String dateStr = TransactionHistoryService.formatTxnDate(date, withTime: false);
    final String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final StringBuffer sb = StringBuffer();
    if (isManualTest) {
      sb.writeln('🌙 *TEST: EOD SETTLEMENT REPORT*');
    } else {
      sb.writeln('🌙 *INYA-TECH EOD SETTLEMENT REPORT*');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📅 *Settlement Date:* `$dateStr`');
    sb.writeln('⏰ *Report Generated:* `$timeStr`\n');

    sb.writeln('💰 *Total Collections:* ₹${TransactionHistoryService.formatCurrency(totalAmount)}');
    sb.writeln('🧾 *Credited Payments:* *$count transactions*');
    if (highestAmount > 0) {
      sb.writeln('🔝 *Highest Single Payment:* ₹${TransactionHistoryService.formatCurrency(highestAmount)}');
    }
    if (forwardedLogs.isNotEmpty) {
      sb.writeln('⏱️ *First Payment:* `$firstTime`  |  *Last:* `$lastTime`');
    }
    if (filteredLogs.isNotEmpty) {
      sb.writeln('🚫 *Filtered (OTP/Spam):* ${filteredLogs.length}');
    }
    if (failedLogs.isNotEmpty) {
      sb.writeln('⚠️ *Failed / Queued:* ${failedLogs.length}');
    }

    sb.writeln('\n📱 *Terminal:* $manufacturer $model');
    sb.writeln('🔋 *Battery:* $batteryText');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('_Daily automated merchant settlement report._');

    return sb.toString();
  }

  /// Send EOD Settlement report to all active Telegram recipients
  static Future<Map<String, int>> sendEodReport({
    bool isManualTest = false,
    DateTime? targetDate,
  }) async {
    final message = await buildEodReportMessage(
      targetDate: targetDate,
      isManualTest: isManualTest,
    );

    final result = await SettingsService.sendBroadcastMessage(message: message);

    if (!isManualTest) {
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyEodLastSentDate, dateKey);
      } catch (e) {
        debugPrint('Error recording EOD last sent date: $e');
      }
    }

    return result;
  }

  /// Start EOD scheduler and watchdog
  static Future<void> startScheduler() async {
    stopScheduler();
    final enabled = await isEodEnabled();
    if (!enabled) return;

    _scheduleNextRun();

    // 15-minute watchdog to guarantee report dispatch even after deep sleep / app pause
    _watchdogTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      final isStillEnabled = await isEodEnabled();
      if (!isStillEnabled) return;

      final now = DateTime.now();
      final targetHour = await getEodHour();
      final targetMinute = await getEodMinute();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final lastSent = await getLastSentDate();
      final isPastTargetTime = now.hour > targetHour || (now.hour == targetHour && now.minute >= targetMinute);

      if (isPastTargetTime && lastSent != todayKey) {
        debugPrint('EOD Watchdog: Triggering missed settlement report for $todayKey');
        await sendEodReport(isManualTest: false);
      }
    });
  }

  static Future<void> _scheduleNextRun() async {
    _scheduledTimer?.cancel();

    final now = DateTime.now();
    final targetHour = await getEodHour();
    final targetMinute = await getEodMinute();

    DateTime nextRun = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
    if (now.isAfter(nextRun)) {
      // If already past today's scheduled time, schedule for tomorrow
      nextRun = nextRun.add(const Duration(days: 1));
    }

    final delay = nextRun.difference(now);
    debugPrint('EOD Scheduler: Next report scheduled in ${delay.inHours}h ${delay.inMinutes % 60}m (at $nextRun)');

    _scheduledTimer = Timer(delay, () async {
      final enabled = await isEodEnabled();
      if (enabled) {
        await sendEodReport(isManualTest: false);
      }
      _scheduleNextRun();
    });
  }

  /// Stop all EOD timers
  static void stopScheduler() {
    _scheduledTimer?.cancel();
    _scheduledTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }
}
