import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/queued_message.dart';
import '../models/transaction_log.dart';
import 'settings_service.dart';
import 'transaction_history_service.dart';

class OfflineQueueService {
  static const String keyQueue = 'offline_sms_queue';
  static const int maxRetries = 15;
  static Timer? _watchdogTimer;
  static bool _isProcessing = false;

  /// Fetch all queued messages from storage
  static Future<List<QueuedMessage>> getQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(keyQueue);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        return list
            .map((item) => QueuedMessage.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading offline queue: $e');
    }
    return [];
  }

  /// Save full queue to storage
  static Future<void> saveQueue(List<QueuedMessage> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> maps =
          queue.map((item) => item.toMap()).toList();
      await prefs.setString(keyQueue, json.encode(maps));
    } catch (e) {
      debugPrint('Error saving offline queue: $e');
    }
  }

  /// Add a failed or offline SMS to the persistent retry queue
  static Future<QueuedMessage> enqueueMessage({
    required String rawSms,
    required String formattedTelegramMessage,
    required String sender,
    required String amount,
    required String txnId,
    required List<String> targetChatIds,
    List<String> alreadyDelivered = const [],
    String? initialError,
  }) async {
    final queue = await getQueue();
    final queuedMsg = QueuedMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rawSms: rawSms,
      formattedTelegramMessage: formattedTelegramMessage,
      sender: sender,
      amount: amount,
      txnId: txnId,
      targetChatIds: targetChatIds,
      deliveredChatIds: alreadyDelivered,
      createdAt: DateTime.now(),
      lastAttemptAt: DateTime.now(),
      retryCount: 1,
      lastError: initialError ?? 'Network offline during receipt',
      status: QueueStatus.pending,
    );

    queue.add(queuedMsg);
    await saveQueue(queue);
    debugPrint('Queued SMS for offline retry: [ID: ${queuedMsg.id}]');
    return queuedMsg;
  }

  /// Get count of pending queued messages
  static Future<int> getPendingCount() async {
    final queue = await getQueue();
    return queue.where((m) => m.status != QueueStatus.sent && !m.isFullyDelivered).length;
  }

  /// Process and retry all pending queued messages
  static Future<Map<String, int>> processQueue() async {
    if (_isProcessing) {
      return {'processed': 0, 'delivered': 0, 'failed': 0};
    }

    _isProcessing = true;
    int deliveredCount = 0;
    int failedCount = 0;

    try {
      final botToken = await SettingsService.getBotToken();
      if (botToken.trim().isEmpty) {
        _isProcessing = false;
        return {'processed': 0, 'delivered': 0, 'failed': 0};
      }

      final queue = await getQueue();
      if (queue.isEmpty) {
        _isProcessing = false;
        return {'processed': 0, 'delivered': 0, 'failed': 0};
      }

      final List<QueuedMessage> updatedQueue = [];

      for (final item in queue) {
        if (item.isFullyDelivered || item.status == QueueStatus.sent) {
          // Keep sent items for a while if needed or purge
          continue;
        }

        final pendingChatIds = item.pendingChatIds;
        final List<String> newlyDelivered = List.from(item.deliveredChatIds);
        String? errorReason;

        final String timeFormatted =
            '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';
        final String delayedHeader =
            '⚠️ *[OFFLINE QUEUE AUTO-RECOVERED]*\n_Originally received at: $timeFormatted (Delayed Delivery)_\n\n';
        final String fullTextToSend = '$delayedHeader${item.formattedTelegramMessage}';

        for (final chatId in pendingChatIds) {
          try {
            final Uri url = Uri.parse(
              'https://api.telegram.org/bot${botToken.trim()}/sendMessage?chat_id=${chatId.trim()}&parse_mode=Markdown&text=${Uri.encodeComponent(fullTextToSend)}',
            );

            final response = await http
                .get(url)
                .timeout(const Duration(seconds: 8));

            if (response.statusCode == 200) {
              newlyDelivered.add(chatId);
              deliveredCount++;
              debugPrint('Queue item ${item.id} delivered to $chatId');
            } else {
              errorReason = 'HTTP ${response.statusCode}: ${response.body}';
              failedCount++;
            }
          } catch (e) {
            errorReason = e.toString();
            failedCount++;
          }
        }

        final isComplete = item.targetChatIds.every((id) => newlyDelivered.contains(id));

        if (isComplete) {
          // Update transaction history
          await _updateHistoryLogDelivered(item);
        } else {
          final updated = item.copyWith(
            deliveredChatIds: newlyDelivered,
            retryCount: item.retryCount + 1,
            lastAttemptAt: DateTime.now(),
            lastError: errorReason,
            status: (item.retryCount + 1 >= maxRetries)
                ? QueueStatus.failed
                : QueueStatus.retrying,
          );
          updatedQueue.add(updated);
        }
      }

      await saveQueue(updatedQueue);
    } catch (e) {
      debugPrint('Error processing offline queue: $e');
    } finally {
      _isProcessing = false;
    }

    return {
      'processed': deliveredCount + failedCount,
      'delivered': deliveredCount,
      'failed': failedCount,
    };
  }

  /// Update corresponding transaction history log entry when queue item is delivered
  static Future<void> _updateHistoryLogDelivered(QueuedMessage msg) async {
    try {
      final logs = await TransactionHistoryService.getLogs();
      for (int i = 0; i < logs.length; i++) {
        if (logs[i].rawBody == msg.rawSms || (msg.txnId.isNotEmpty && logs[i].txnId == msg.txnId)) {
          final updated = TransactionLog(
            id: logs[i].id,
            sender: logs[i].sender,
            rawBody: logs[i].rawBody,
            amount: logs[i].amount,
            formattedAmount: logs[i].formattedAmount,
            txnId: logs[i].txnId,
            bank: logs[i].bank,
            status: TransactionStatus.forwarded,
            statusReason: '✅ Delivered from Offline Queue (Network Recovered)',
            timestamp: logs[i].timestamp,
            isCredit: true,
          );
          logs[i] = updated;
          break;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final maps = logs.map((l) => l.toMap()).toList();
      await prefs.setString(TransactionHistoryService.keyLogs, json.encode(maps));
    } catch (e) {
      debugPrint('Error updating history log after queue drain: $e');
    }
  }

  /// Start background queue watchdog timer (runs every 20 seconds)
  static void startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final count = await getPendingCount();
      if (count > 0) {
        await processQueue();
      }
    });
  }

  /// Stop queue watchdog
  static void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  /// Clear all queued messages
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyQueue);
  }
}
