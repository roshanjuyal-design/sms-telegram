import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.example.sms_to_telegram/sms');

  setUp(() {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isIgnoringBatteryOptimizations':
          return true;
        case 'checkOverlayPermission':
          return true;
        case 'requestPermissions':
          return true;
        case 'startForegroundService':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('SMS forwarder iOS UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify iOS Navigation Bar & Tabs
    expect(find.text('InyaTech'), findsWidgets);
    expect(find.text('Monitor'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Soundbox'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Verify Monitor Screen elements
    expect(find.text('System Active'), findsOneWidget);
    expect(find.text('24/7 Monitoring'), findsOneWidget);
    expect(find.text('Developed by Roshan Juyal'), findsOneWidget);
    expect(find.text('Test Payment Alert & Voice'), findsOneWidget);
  });

  testWidgets('AppLockScreen prompts for passcode and unlocks with 5440', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('InyaTech Security'), findsOneWidget);
    expect(find.text('Enter 4-digit Passcode to access terminal'), findsOneWidget);

    // Enter digits 5, 4, 4, 0
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();

    // Unlocks and reveals main UI
    expect(find.text('Monitor'), findsOneWidget);
  });

  group('parsePaymentSms tests', () {
    test('correctly parses sample payment SMS', () {
      const sampleSms =
          'UPI payment of Rs. 1000 received from scharan1631@axl on 01-SEP-2026 11:31:16: with transaction ID 046661256251 - Union Bank of India.';
      final result = parsePaymentSms(sampleSms);

      expect(result, contains('💰 *UBI Payment Credited!*'));
      expect(result, contains('💵 *Amount:* ₹1000'));
      expect(result, contains('👤 *From:* scharan1631@axl'));
      expect(result, contains('🆔 *Txn ID:* `046661256251`'));
    });
  });

  group('shouldForwardSms filter tests', () {
    test('blocks OTP and verification code messages', () {
      expect(shouldForwardSms('Your OTP for Union Bank UPI login is 482910.'), isFalse);
      expect(shouldForwardSms('Do not share your verification code 123456 - UBI'), isFalse);
      expect(shouldForwardSms('Your OTP for Netflix login is 987123'), isFalse);
    });

    test('blocks Debit messages', () {
      expect(shouldForwardSms('Rs. 500 debited from your A/C ... via UPI - Union Bank of India'), isFalse);
      expect(shouldForwardSms('Amount Rs 1200 withdrawn from ATM - UBI'), isFalse);
      expect(shouldForwardSms('Rs 350 spent on card ... - Union Bank'), isFalse);
    });

    test('blocks Non-UBI messages even if credited', () {
      expect(shouldForwardSms('Dear Customer, your SBI A/c has been credited with Rs 500'), isFalse);
      expect(shouldForwardSms('HDFC Bank: Rs 2000 credited to account'), isFalse);
      expect(shouldForwardSms('Hey, are you free this weekend?'), isFalse);
    });

    test('allows UBI credited SMS via body or sender header', () {
      expect(
        shouldForwardSms(
          'UPI payment of Rs. 1000 received from scharan1631@axl on 01-SEP-2026 11:31:16: with transaction ID 046661256251 - Union Bank of India.',
        ),
        isTrue,
      );
      expect(
        shouldForwardSms(
          'Dear Customer, your A/C has been credited with Rs 5000.00 on 27-09-2026 by UPI - Union Bank',
        ),
        isTrue,
      );
      expect(
        shouldForwardSms(
          'Rs 1200 deposited into your A/C on 27-09-2026',
          'VK-UBIN',
        ),
        isTrue,
      );
    });
  });
}
