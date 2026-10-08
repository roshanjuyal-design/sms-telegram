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

    test('formats currency and dates accurately', () {
      expect(TransactionHistoryService.formatCurrency(6000.0), '6,000.00');
      expect(TransactionHistoryService.formatCurrency(13750.0), '13,750.00');
      expect(TransactionHistoryService.formatCurrency(90000.0), '90,000.00');
      expect(TransactionHistoryService.formatCurrency(490.0), '490.00');

      final dt = DateTime(2026, 10, 7, 15, 31);
      expect(TransactionHistoryService.formatTxnDate(dt), '07-10-2026 15:31');
    });

    test('generates clean merchant statement text and Excel table matching Screenshot 2', () async {
      final log = TransactionLog(
        id: '1',
        sender: '9676271296-2@ybl',
        rawBody: 'UPI payment of Rs. 13750 received...',
        amount: 13750.0,
        formattedAmount: '13750',
        txnId: '099755675527',
        bank: 'Union Bank of India',
        status: TransactionStatus.forwarded,
        statusReason: 'Payment from UPI',
        timestamp: DateTime(2026, 10, 7, 15, 31),
        isCredit: true,
      );

      await TransactionHistoryService.addLog(log);

      final statementText = await TransactionHistoryService.exportCleanStatementText();
      expect(statementText, contains('UPI TRANSACTIONS MERCHANT STATEMENT'));
      expect(statementText, contains('PAYER   : 9676271296-2@ybl'));
      expect(statementText, contains('RRN     : 099755675527'));
      expect(statementText, contains('TXN AMT : ₹13,750.00'));

      final excelTable = await TransactionHistoryService.exportExcelTable();
      expect(excelTable, contains('TXN DT\tPAYER\tRRN\tTXN AMT\tMDR\tGST\tNET AMT\tREMARKS'));
      expect(excelTable, contains('07-10-2026 15:31\t9676271296-2@ybl\t099755675527\t13,750.00\t0.00\t0.00\t13,750.00\tPayment from PhonePe / UPI'));
    });

    test('calculates yesterday and all-time statistics with alias keys', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final todayLog = TransactionLog(
        id: 'today_1',
        sender: 'User Today',
        rawBody: 'Credit Rs 500',
        amount: 500.0,
        formattedAmount: '500',
        txnId: 'T1',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: now,
        isCredit: true,
      );

      final yesterdayLog = TransactionLog(
        id: 'yest_1',
        sender: 'User Yesterday',
        rawBody: 'Credit Rs 1200',
        amount: 1200.0,
        formattedAmount: '1200',
        txnId: 'Y1',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: yesterday,
        isCredit: true,
      );

      final yesterdayFiltered = TransactionLog(
        id: 'yest_filtered',
        sender: 'VK-UBIN',
        rawBody: 'OTP 1234',
        amount: 0.0,
        formattedAmount: '0',
        txnId: '',
        bank: 'Union Bank',
        status: TransactionStatus.filtered,
        statusReason: 'Filtered',
        timestamp: yesterday,
        isCredit: false,
      );

      await TransactionHistoryService.addLog(todayLog);
      await TransactionHistoryService.addLog(yesterdayLog);
      await TransactionHistoryService.addLog(yesterdayFiltered);

      final stats = await TransactionHistoryService.getStats();

      // Today
      expect(stats['todayTotal'], 500.0);
      expect(stats['todayForwardedCount'], 1);

      // Yesterday
      expect(stats['yesterdayTotal'], 1200.0);
      expect(stats['yesterdayForwardedCount'], 1);
      expect(stats['yesterdayFilteredCount'], 1);

      // All-Time (with backwards-compatible aliases)
      expect(stats['allTimeTotal'], 1700.0);
      expect(stats['totalAmount'], 1700.0);
      expect(stats['totalForwarded'], 2);
      expect(stats['forwardedCount'], 2);
    });

    test('exports customLogs when provided for date filtering', () async {
      final logA = TransactionLog(
        id: 'a',
        sender: 'Payer A',
        rawBody: 'Credit Rs 100',
        amount: 100.0,
        formattedAmount: '100',
        txnId: 'TXN_A',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime(2026, 10, 6, 10, 0),
        isCredit: true,
      );
      final logB = TransactionLog(
        id: 'b',
        sender: 'Payer B',
        rawBody: 'Credit Rs 200',
        amount: 200.0,
        formattedAmount: '200',
        txnId: 'TXN_B',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: DateTime(2026, 10, 7, 10, 0),
        isCredit: true,
      );

      await TransactionHistoryService.addLog(logA);
      await TransactionHistoryService.addLog(logB);

      // Export only logB as customLogs
      final statement = await TransactionHistoryService.exportCleanStatementText(
        customLogs: [logB],
      );
      expect(statement, contains('PAYER   : Payer B'));
      expect(statement, isNot(contains('PAYER   : Payer A')));
      expect(statement, contains('Total Credited : ₹200.00'));
    });
  });
}
