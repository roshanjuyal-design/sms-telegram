import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_log.dart';

class TransactionHistoryService {
  static const String keyLogs = 'transaction_history_logs';
  static const int maxLogEntries = 500;

  /// Fetch all stored transaction logs sorted newest first
  static Future<List<TransactionLog>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(keyLogs);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        final logs = list
            .map((item) => TransactionLog.fromMap(item as Map<String, dynamic>))
            .toList();
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return logs;
      }
    } catch (e) {
      debugPrint('Error loading transaction logs: $e');
    }
    return [];
  }

  /// Add a new transaction log entry
  static Future<void> addLog(TransactionLog log) async {
    try {
      final logs = await getLogs();
      logs.insert(0, log);

      // Keep only up to maxLogEntries to maintain optimal performance
      if (logs.length > maxLogEntries) {
        logs.removeRange(maxLogEntries, logs.length);
      }

      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> maps = logs.map((l) => l.toMap()).toList();
      await prefs.setString(keyLogs, json.encode(maps));
    } catch (e) {
      debugPrint('Error saving transaction log: $e');
    }
  }

  /// Delete a single log entry by ID
  static Future<void> deleteLog(String id) async {
    try {
      final logs = await getLogs();
      logs.removeWhere((l) => l.id == id);
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> maps = logs.map((l) => l.toMap()).toList();
      await prefs.setString(keyLogs, json.encode(maps));
    } catch (e) {
      debugPrint('Error deleting log: $e');
    }
  }

  /// Clear all transaction history logs
  static Future<void> clearLogs() async {
    await clearAllLogs();
  }

  /// Clear all transaction history logs
  static Future<void> clearAllLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyLogs);
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }

  /// Export transaction logs as CSV formatted string
  static Future<String> exportLogsAsCsv() async {
    final logs = await getLogs();
    final StringBuffer sb = StringBuffer();
    sb.writeln('ID,Timestamp,Status,Amount,Sender,TxnID,Bank,Reason,RawSMS');
    for (final log in logs) {
      final String safeRaw = log.rawBody.replaceAll('"', '""').replaceAll('\n', ' ');
      final String safeReason = log.statusReason.replaceAll('"', '""');
      final String statusStr = log.status.name;
      sb.writeln('"${log.id}","${log.timestamp.toIso8601String()}","$statusStr","${log.formattedAmount}","${log.sender}","${log.txnId}","${log.bank}","$safeReason","$safeRaw"');
    }
    return sb.toString();
  }

  /// Helper to parse SMS text and create a structured TransactionLog
  static TransactionLog createLogFromSms({
    required String rawBody,
    required String sender,
    required bool isForwarded,
    required String statusReason,
    bool isFailed = false,
  }) {
    final RegExp amountRegex = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    );
    final RegExp senderRegex = RegExp(
      r'(?:received from|from)\s+([^\s,:]+)',
      caseSensitive: false,
    );
    final RegExp txnRegex = RegExp(
      r'(?:transaction\s*ID|Txn\s*ID|Ref(?:\s*No)?|UPI\s*Ref)[:\s]+([a-zA-Z0-9]+)',
      caseSensitive: false,
    );

    final Match? amountMatch = amountRegex.firstMatch(rawBody);
    final Match? senderMatch = senderRegex.firstMatch(rawBody);
    final Match? txnMatch = txnRegex.firstMatch(rawBody);

    final String formattedAmount = amountMatch?.group(1) ?? '0';
    final double amount = double.tryParse(formattedAmount.replaceAll(',', '')) ?? 0.0;
    final String extractedSender = senderMatch?.group(1) ?? sender;
    final String txnId = txnMatch?.group(1) ?? '';

    TransactionStatus status = TransactionStatus.forwarded;
    if (isFailed) {
      status = TransactionStatus.failed;
    } else if (!isForwarded) {
      status = TransactionStatus.filtered;
    }

    return TransactionLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: extractedSender.isNotEmpty ? extractedSender : sender,
      rawBody: rawBody,
      amount: amount,
      formattedAmount: formattedAmount,
      txnId: txnId,
      bank: 'Union Bank of India',
      status: status,
      statusReason: statusReason,
      timestamp: DateTime.now(),
      isCredit: isForwarded,
    );
  }

  /// Calculate summary statistics (Today, Total, Counts)
  static Future<Map<String, dynamic>> getStats() async {
    final logs = await getLogs();
    final now = DateTime.now();

    double todayTotal = 0.0;
    int todayForwardedCount = 0;
    int todayFilteredCount = 0;

    double allTimeTotal = 0.0;
    int totalForwarded = 0;
    int totalFiltered = 0;
    int totalFailed = 0;

    for (final log in logs) {
      final isToday = log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;

      if (log.status == TransactionStatus.forwarded) {
        allTimeTotal += log.amount;
        totalForwarded++;

        if (isToday) {
          todayTotal += log.amount;
          todayForwardedCount++;
        }
      } else if (log.status == TransactionStatus.filtered) {
        totalFiltered++;
        if (isToday) {
          todayFilteredCount++;
        }
      } else if (log.status == TransactionStatus.failed) {
        totalFailed++;
      }
    }

    return {
      'todayTotal': todayTotal,
      'todayForwardedCount': todayForwardedCount,
      'todayFilteredCount': todayFilteredCount,
      'allTimeTotal': allTimeTotal,
      'totalForwarded': totalForwarded,
      'totalFiltered': totalFiltered,
      'totalFailed': totalFailed,
      'totalLogs': logs.length,
    };
  }
}
