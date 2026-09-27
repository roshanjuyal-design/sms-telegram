import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/models/queued_message.dart';
import 'package:sms_to_telegram/services/offline_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('QueuedMessage Model Tests', () {
    test('Correctly computes isFullyDelivered and pendingChatIds', () {
      final msg = QueuedMessage(
        id: '123',
        rawSms: 'UPI Rs 500 received',
        formattedTelegramMessage: 'Payment Credited',
        sender: 'VK-UBIN',
        amount: '500',
        txnId: 'TXN123',
        targetChatIds: ['chat1', 'chat2', 'chat3'],
        deliveredChatIds: ['chat1'],
        createdAt: DateTime.now(),
      );

      expect(msg.isFullyDelivered, false);
      expect(msg.pendingChatIds, ['chat2', 'chat3']);

      final updated = msg.copyWith(
        deliveredChatIds: ['chat1', 'chat2', 'chat3'],
        status: QueueStatus.sent,
      );

      expect(updated.isFullyDelivered, true);
      expect(updated.pendingChatIds, isEmpty);
      expect(updated.status, QueueStatus.sent);
    });

    test('Serialization and deserialization works correctly', () {
      final original = QueuedMessage(
        id: 'msg_999',
        rawSms: 'UPI payment received',
        formattedTelegramMessage: 'Formatted text',
        sender: 'UBIN',
        amount: '1500',
        txnId: 'TX999',
        targetChatIds: ['111', '222'],
        deliveredChatIds: ['111'],
        createdAt: DateTime(2026, 9, 27, 10, 30),
        lastAttemptAt: DateTime(2026, 9, 27, 10, 31),
        retryCount: 2,
        lastError: 'SocketException',
        status: QueueStatus.retrying,
      );

      final jsonStr = original.toJson();
      final restored = QueuedMessage.fromJson(jsonStr);

      expect(restored.id, original.id);
      expect(restored.rawSms, original.rawSms);
      expect(restored.amount, original.amount);
      expect(restored.txnId, original.txnId);
      expect(restored.targetChatIds, original.targetChatIds);
      expect(restored.deliveredChatIds, original.deliveredChatIds);
      expect(restored.retryCount, 2);
      expect(restored.status, QueueStatus.retrying);
      expect(restored.lastError, 'SocketException');
    });
  });

  group('OfflineQueueService Tests', () {
    test('Enqueues and reads queued messages', () async {
      expect(await OfflineQueueService.getPendingCount(), 0);

      final queued = await OfflineQueueService.enqueueMessage(
        rawSms: 'UPI Rs 200 received',
        formattedTelegramMessage: 'Telegram Alert',
        sender: 'VK-UBIN',
        amount: '200',
        txnId: 'TXN200',
        targetChatIds: ['chatA', 'chatB'],
        initialError: 'No internet',
      );

      expect(queued.status, QueueStatus.pending);
      expect(await OfflineQueueService.getPendingCount(), 1);

      final queue = await OfflineQueueService.getQueue();
      expect(queue.length, 1);
      expect(queue.first.amount, '200');
      expect(queue.first.targetChatIds, ['chatA', 'chatB']);

      // Clear queue
      await OfflineQueueService.clearQueue();
      expect(await OfflineQueueService.getPendingCount(), 0);
      expect((await OfflineQueueService.getQueue()).length, 0);
    });
  });
}
