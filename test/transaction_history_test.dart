import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/models/transaction_log.dart';
import 'package:sms_to_telegram/services/transaction_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TransactionHistoryService tests', () {
    test('creates log accurately from credit payment SMS', () {
      const sms =
          'UPI payment of Rs. 1500 received from user1@axl on 01-SEP-2026 11:31:16: with transaction ID 9988776655 - Union Bank of India.';
      final log = TransactionHistoryService.createLogFromSms(
        rawBody: sms,
        sender: 'VK-UBIN',
        isForwarded: true,
        statusReason: 'Forwarded to Telegram',
      );

      expect(log.amount, 1500.0);
      expect(log.formattedAmount, '1500');
      expect(log.txnId, '9988776655');
      expect(log.status, TransactionStatus.forwarded);
      expect(log.isCredit, isTrue);
    });

    test('creates log accurately from filtered non-credit SMS', () {
      const sms = 'Your OTP for UBI login is 123456';
      final log = TransactionHistoryService.createLogFromSms(
        rawBody: sms,
        sender: 'VK-UBIN',
        isForwarded: false,
        statusReason: 'Filtered: OTP',
      );

      expect(log.status, TransactionStatus.filtered);
      expect(log.isCredit, isFalse);
    });

    test('adds, retrieves, and calculates statistics', () async {
      final log1 = TransactionLog(
        id: '1',
        sender: 'User A',
        rawBody: 'Credit Rs 500',
        amount: 500.0,
        formattedAmount: '500',
        txnId: 'TXN1',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime.now(),
        isCredit: true,
      );

      final log2 = TransactionLog(
        id: '2',
        sender: 'User B',
        rawBody: 'Credit Rs 1500',
        amount: 1500.0,
        formattedAmount: '1500',
        txnId: 'TXN2',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime.now(),
        isCredit: true,
      );

      final log3 = TransactionLog(
        id: '3',
        sender: 'VK-UBIN',
        rawBody: 'OTP 1234',
        amount: 0.0,
        formattedAmount: '0',
        txnId: '',
        bank: 'Union Bank',
        status: TransactionStatus.filtered,
        statusReason: 'Filtered',
        timestamp: DateTime.now(),
        isCredit: false,
      );

      await TransactionHistoryService.addLog(log1);
      await TransactionHistoryService.addLog(log2);
      await TransactionHistoryService.addLog(log3);

      final logs = await TransactionHistoryService.getLogs();
      expect(logs.length, 3);

      final stats = await TransactionHistoryService.getStats();
      expect(stats['todayTotal'], 2000.0);
      expect(stats['todayForwardedCount'], 2);
      expect(stats['todayFilteredCount'], 1);
      expect(stats['totalForwarded'], 2);
    });

    test('deletes and clears logs properly', () async {
      final log = TransactionLog(
        id: 'test_delete',
        sender: 'User',
        rawBody: 'Test SMS',
        amount: 100.0,
        formattedAmount: '100',
        txnId: 'TXN9',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime.now(),
      );

      await TransactionHistoryService.addLog(log);
      var logs = await TransactionHistoryService.getLogs();
      expect(logs.length, 1);

      await TransactionHistoryService.deleteLog('test_delete');
      logs = await TransactionHistoryService.getLogs();
      expect(logs.length, 0);

      await TransactionHistoryService.addLog(log);
      await TransactionHistoryService.clearAllLogs();
      logs = await TransactionHistoryService.getLogs();
      expect(logs.isEmpty, isTrue);
    });
  });
}
