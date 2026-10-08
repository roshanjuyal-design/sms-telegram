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

  /// Format amount in standard currency style with commas (e.g. 13,750.00)
  static String formatCurrency(double amount) {
    final String str = amount.toStringAsFixed(2);
    final parts = str.split('.');
    String whole = parts[0];
    final String dec = parts.length > 1 ? parts[1] : '00';

    if (whole.length > 3) {
      final String lastThree = whole.substring(whole.length - 3);
      String remaining = whole.substring(0, whole.length - 3);
      final reg = RegExp(r'(\d+?)(?=(\d{2})+(?!\d))');
      remaining = remaining.replaceAllMapped(reg, (Match m) => '${m[1]},');
      whole = '$remaining,$lastThree';
    }
    return '$whole.$dec';
  }

  /// Format date as DD-MM-YYYY HH:mm or DD-MM-YYYY
  static String formatTxnDate(DateTime dt, {bool withTime = true}) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    if (!withTime) {
      return '$day-$month-$year';
    }
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  /// Export as clean Merchant Statement Text (clean format for WhatsApp, Email, Notes)
  static Future<String> exportCleanStatementText({
    bool creditedOnly = false,
    List<TransactionLog>? customLogs,
  }) async {
    var logs = customLogs ?? await getLogs();
    if (creditedOnly) {
      logs = logs.where((l) => l.status == TransactionStatus.forwarded).toList();
    }

    final double totalCredited = logs
        .where((l) => l.status == TransactionStatus.forwarded)
        .fold(0.0, (sum, l) => sum + l.amount);

    final String dateStr = formatTxnDate(DateTime.now(), withTime: false);
    final StringBuffer sb = StringBuffer();

    sb.writeln('════════════════════════════════════════════════════════════');
    sb.writeln('            UPI TRANSACTIONS MERCHANT STATEMENT            ');
    sb.writeln('════════════════════════════════════════════════════════════');
    sb.writeln('Statement Date : $dateStr');
    sb.writeln('Total Entries  : ${logs.length}');
    sb.writeln('Total Credited : ₹${formatCurrency(totalCredited)}');
    sb.writeln('────────────────────────────────────────────────────────────\n');

    if (logs.isEmpty) {
      sb.writeln('No transaction records found.\n');
    } else {
      for (int i = 0; i < logs.length; i++) {
        final log = logs[i];
        final String dt = formatTxnDate(log.timestamp);
        final String payer = log.sender.isNotEmpty ? log.sender : 'Unknown';
        final String rrn = log.txnId.isNotEmpty ? log.txnId : '-';
        final String amt = '₹${formatCurrency(log.amount)}';
        final String status = log.status == TransactionStatus.forwarded
            ? 'Credited (UPI Payment)'
            : 'Filtered (${log.statusReason})';

        sb.writeln('${i + 1}. TXN DT  : $dt');
        sb.writeln('   PAYER   : $payer');
        sb.writeln('   RRN     : $rrn');
        sb.writeln('   TXN AMT : $amt');
        sb.writeln('   NET AMT : $amt');
        sb.writeln('   REMARKS : $status');
        sb.writeln('────────────────────────────────────────────────────────────');
      }
    }

    sb.writeln('\n============================================================');
    sb.writeln('TOTAL RECEIVED: ₹${formatCurrency(totalCredited)}');
    sb.writeln('============================================================');

    return sb.toString();
  }

  /// Export as Tab-Delimited Table matching Screenshot 2 (TXN DT, PAYER, RRN, TXN AMT, MDR, GST, NET AMT, REMARKS)
  /// Pastes directly into Excel / Google Sheets with proper columns!
  static Future<String> exportExcelTable({
    bool creditedOnly = false,
    List<TransactionLog>? customLogs,
  }) async {
    var logs = customLogs ?? await getLogs();
    if (creditedOnly) {
      logs = logs.where((l) => l.status == TransactionStatus.forwarded).toList();
    }

    final StringBuffer sb = StringBuffer();
    // Headers matching Screenshot 2
    sb.writeln('TXN DT\tPAYER\tRRN\tTXN AMT\tMDR\tGST\tNET AMT\tREMARKS');

    for (final log in logs) {
      final String dt = formatTxnDate(log.timestamp);
      final String payer = log.sender.isNotEmpty ? log.sender : 'Unknown';
      final String rrn = log.txnId.isNotEmpty ? log.txnId : '-';
      final String amt = formatCurrency(log.amount);
      const String mdr = '0.00';
      const String gst = '0.00';
      final String netAmt = amt;
      final String remarks = log.status == TransactionStatus.forwarded
          ? 'Payment from PhonePe / UPI'
          : log.statusReason;

      sb.writeln('$dt\t$payer\t$rrn\t$amt\t$mdr\t$gst\t$netAmt\t$remarks');
    }

    return sb.toString();
  }

  /// Export as Clean CSV matching Screenshot 2 columns
  static Future<String> exportCleanCsv({
    bool creditedOnly = false,
    List<TransactionLog>? customLogs,
  }) async {
    var logs = customLogs ?? await getLogs();
    if (creditedOnly) {
      logs = logs.where((l) => l.status == TransactionStatus.forwarded).toList();
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('TXN DT,PAYER,RRN,TXN AMT,MDR,GST,NET AMT,REMARKS');

    for (final log in logs) {
      final String dt = formatTxnDate(log.timestamp);
      final String payer = (log.sender.isNotEmpty ? log.sender : 'Unknown').replaceAll('"', '""');
      final String rrn = (log.txnId.isNotEmpty ? log.txnId : '-').replaceAll('"', '""');
      final String amt = formatCurrency(log.amount);
      const String mdr = '0.00';
      const String gst = '0.00';
      final String netAmt = amt;
      final String remarks = (log.status == TransactionStatus.forwarded
          ? 'Payment from PhonePe / UPI'
          : log.statusReason).replaceAll('"', '""');

      sb.writeln('"$dt","$payer","$rrn","$amt","$mdr","$gst","$netAmt","$remarks"');
    }

    return sb.toString();
  }

  /// Export transaction logs as CSV formatted string
  static Future<String> exportLogsAsCsv() async {
    return exportCleanCsv();
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

  /// Calculate summary statistics (Today, Yesterday, All-Time, Counts)
  static Future<Map<String, dynamic>> getStats() async {
    final logs = await getLogs();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    double todayTotal = 0.0;
    int todayForwardedCount = 0;
    int todayFilteredCount = 0;

    double yesterdayTotal = 0.0;
    int yesterdayForwardedCount = 0;
    int yesterdayFilteredCount = 0;

    double allTimeTotal = 0.0;
    int totalForwarded = 0;
    int totalFiltered = 0;
    int totalFailed = 0;

    for (final log in logs) {
      final isToday = log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;

      final isYesterday = log.timestamp.year == yesterday.year &&
          log.timestamp.month == yesterday.month &&
          log.timestamp.day == yesterday.day;

      if (log.status == TransactionStatus.forwarded) {
        allTimeTotal += log.amount;
        totalForwarded++;

        if (isToday) {
          todayTotal += log.amount;
          todayForwardedCount++;
        } else if (isYesterday) {
          yesterdayTotal += log.amount;
          yesterdayForwardedCount++;
        }
      } else if (log.status == TransactionStatus.filtered) {
        totalFiltered++;
        if (isToday) {
          todayFilteredCount++;
        } else if (isYesterday) {
          yesterdayFilteredCount++;
        }
      } else if (log.status == TransactionStatus.failed) {
        totalFailed++;
      }
    }

    return {
      'todayTotal': todayTotal,
      'todayForwardedCount': todayForwardedCount,
      'todayFilteredCount': todayFilteredCount,
      'yesterdayTotal': yesterdayTotal,
      'yesterdayForwardedCount': yesterdayForwardedCount,
      'yesterdayFilteredCount': yesterdayFilteredCount,
      'allTimeTotal': allTimeTotal,
      'totalAmount': allTimeTotal, // Backwards compatible alias
      'totalForwarded': totalForwarded,
      'forwardedCount': totalForwarded, // Backwards compatible alias
      'totalFiltered': totalFiltered,
      'totalFailed': totalFailed,
      'totalLogs': logs.length,
    };
  }
}
