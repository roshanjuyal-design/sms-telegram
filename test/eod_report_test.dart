import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/models/transaction_log.dart';
import 'package:sms_to_telegram/services/eod_report_service.dart';
import 'package:sms_to_telegram/services/transaction_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EodReportService tests', () {
    test('defaults are configured to enabled at 23:59', () async {
      expect(await EodReportService.isEodEnabled(), isTrue);
      expect(await EodReportService.getEodHour(), 23);
      expect(await EodReportService.getEodMinute(), 59);

      await EodReportService.setEodEnabled(false);
      expect(await EodReportService.isEodEnabled(), isFalse);

      await EodReportService.setEodTime(22, 30);
      expect(await EodReportService.getEodHour(), 22);
      expect(await EodReportService.getEodMinute(), 30);
    });

    test('builds comprehensive EOD settlement markdown message', () async {
      final now = DateTime.now();

      final log1 = TransactionLog(
        id: '1',
        sender: 'User One',
        rawBody: 'Credit Rs 5000',
        amount: 5000.0,
        formattedAmount: '5000',
        txnId: 'TXN111',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: now,
        isCredit: true,
      );

      final log2 = TransactionLog(
        id: '2',
        sender: 'User Two',
        rawBody: 'Credit Rs 25000',
        amount: 25000.0,
        formattedAmount: '25000',
        txnId: 'TXN222',
        bank: 'Union Bank',
        status: TransactionStatus.forwarded,
        statusReason: 'Forwarded',
        timestamp: now.add(const Duration(minutes: 10)),
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
        timestamp: now,
        isCredit: false,
      );

      await TransactionHistoryService.addLog(log1);
      await TransactionHistoryService.addLog(log2);
      await TransactionHistoryService.addLog(log3);

      final report = await EodReportService.buildEodReportMessage(targetDate: now);

      expect(report, contains('INYA-TECH EOD SETTLEMENT REPORT'));
      expect(report, contains('*Total Collections:* ₹30,000.00'));
      expect(report, contains('*Credited Payments:* *2 transactions*'));
      expect(report, contains('*Highest Single Payment:* ₹25,000.00'));
      expect(report, contains('*Filtered (OTP/Spam):* 1'));
    });
  });
}
