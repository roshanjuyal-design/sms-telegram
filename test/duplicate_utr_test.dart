import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/models/transaction_log.dart';
import 'package:sms_to_telegram/services/transaction_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Duplicate UTR & Fraud Detection tests', () {
    test('findExistingTxn correctly locates prior transaction by UTR', () async {
      // 1. Initially empty
      expect(await TransactionHistoryService.findExistingTxn('766508837457'), isNull);

      // 2. Add an original transaction
      final original = TransactionLog(
        id: 'orig_1',
        sender: '9676271296-2@axl',
        rawBody: 'UPI payment of Rs. 2000 received with transaction ID 766508837457',
        amount: 2000.0,
        formattedAmount: '2000',
        txnId: '766508837457',
        bank: 'Union Bank of India',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded to Telegram & Soundbox',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isCredit: true,
      );

      await TransactionHistoryService.addLog(original);

      // 3. Search exact UTR
      final match = await TransactionHistoryService.findExistingTxn('766508837457');
      expect(match, isNotNull);
      expect(match!.id, 'orig_1');
      expect(match.amount, 2000.0);

      // 4. Case insensitive search
      final caseMatch = await TransactionHistoryService.findExistingTxn('766508837457');
      expect(caseMatch, isNotNull);

      // 5. Short/empty search returns null
      expect(await TransactionHistoryService.findExistingTxn(''), isNull);
      expect(await TransactionHistoryService.findExistingTxn('12'), isNull);

      // 6. Non-existent UTR returns null
      expect(await TransactionHistoryService.findExistingTxn('999999999999'), isNull);
    });

    test('duplicate status serializes and deserializes properly', () {
      final dupLog = TransactionLog(
        id: 'dup_1',
        sender: 'scammer@upi',
        rawBody: 'Duplicate SMS body',
        amount: 5000.0,
        formattedAmount: '5000',
        txnId: '123456789012',
        bank: 'Union Bank of India',
        status: TransactionStatus.duplicate,
        statusReason: '⚠️ Duplicate UTR detected',
        timestamp: DateTime.now(),
        isCredit: false,
      );

      final map = dupLog.toMap();
      expect(map['status'], 'duplicate');

      final restored = TransactionLog.fromMap(map);
      expect(restored.status, TransactionStatus.duplicate);
      expect(restored.isCredit, isFalse);
    });

    test('duplicate transactions do not inflate total collections in stats', () async {
      final genuineLog = TransactionLog(
        id: 'genuine',
        sender: 'User',
        rawBody: 'Credit Rs 1000',
        amount: 1000.0,
        formattedAmount: '1000',
        txnId: 'TXN1000',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime.now(),
        isCredit: true,
      );

      final duplicateLog = TransactionLog(
        id: 'fake_dup',
        sender: 'User',
        rawBody: 'Duplicate Credit Rs 1000',
        amount: 1000.0,
        formattedAmount: '1000',
        txnId: 'TXN1000',
        bank: 'Union Bank',
        status: TransactionStatus.duplicate,
        statusReason: '⚠️ Duplicate UTR detected',
        timestamp: DateTime.now(),
        isCredit: false,
      );

      await TransactionHistoryService.addLog(genuineLog);
      await TransactionHistoryService.addLog(duplicateLog);

      final stats = await TransactionHistoryService.getStats();

      // Only the genuine 1000 should be in totals!
      expect(stats['todayTotal'], 1000.0);
      expect(stats['todayForwardedCount'], 1);
      expect(stats['totalDuplicates'], 1);
      expect(stats['allTimeTotal'], 1000.0);
    });
  });
}
