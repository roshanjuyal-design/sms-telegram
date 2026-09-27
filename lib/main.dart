import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'screens/main_ios_shell.dart';
import 'services/settings_service.dart';
import 'services/soundbox_service.dart';
import 'services/transaction_history_service.dart';
import 'theme/ios_theme.dart';

const MethodChannel _channel = MethodChannel('com.example.sms_to_telegram/sms');

/// Helper function to check if 'Display over other apps' permission is granted.
Future<bool> checkOverlayPermission() async {
  try {
    final bool? granted = await _channel.invokeMethod<bool>('checkOverlayPermission');
    return granted ?? false;
  } catch (e) {
    debugPrint('Error checking overlay permission: $e');
    return false;
  }
}

/// Helper function to open system settings for 'Display over other apps' permission.
Future<void> requestOverlayPermission() async {
  try {
    await _channel.invokeMethod('requestOverlayPermission');
  } catch (e) {
    debugPrint('Error requesting overlay permission: $e');
  }
}

/// Helper function to explicitly start the Android Foreground Service.
Future<void> startForegroundService() async {
  try {
    await _channel.invokeMethod('startForegroundService');
  } catch (e) {
    debugPrint('Error starting foreground service: $e');
  }
}

/// Helper function to parse payment SMS and format it for Telegram.
/// Extracts amount, sender (after 'received from' or 'from'), and transaction ID / Ref No.
String parsePaymentSms(String body) {
  // Extract amount (after 'Rs.' or 'INR' or '₹')
  final RegExp amountRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  // Extract sender (after 'received from' or 'from')
  final RegExp senderRegex = RegExp(
    r'(?:received from|from)\s+([^\s,:]+)',
    caseSensitive: false,
  );
  // Extract transaction ID or Ref No
  final RegExp txnRegex = RegExp(
    r'(?:transaction\s*ID|Txn\s*ID|Ref(?:\s*No)?|UPI\s*Ref)[:\s]+([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  final Match? amountMatch = amountRegex.firstMatch(body);
  final Match? senderMatch = senderRegex.firstMatch(body);
  final Match? txnMatch = txnRegex.firstMatch(body);

  final String amount = amountMatch?.group(1) ?? '';
  final String sender = senderMatch?.group(1) ?? '';
  final String txnId = txnMatch?.group(1) ?? '';

  final StringBuffer sb = StringBuffer('💰 *UBI Payment Credited!*\n\n');
  if (amount.isNotEmpty) {
    sb.writeln('💵 *Amount:* ₹$amount');
  }
  if (sender.isNotEmpty) {
    sb.writeln('👤 *From:* $sender');
  }
  if (txnId.isNotEmpty) {
    sb.writeln('🆔 *Txn ID:* `$txnId`');
  }
  sb.writeln('\n📩 *Details:* $body');
  sb.writeln('\n⏰ *Time:* _${DateTime.now().toLocal().toString().split('.').first}_');

  return sb.toString();
}

/// Dispatches the message to all dynamically configured active Telegram chat IDs.
Future<void> sendToTelegram(String message) async {
  final String botToken = await SettingsService.getBotToken();
  final List<String> chatIds = await SettingsService.getActiveChatIds();

  if (botToken.trim().isEmpty || chatIds.isEmpty) {
    debugPrint('Cannot forward to Telegram: Bot token or chat IDs are empty.');
    return;
  }

  for (final String chatId in chatIds) {
    final Uri url = Uri.parse(
      'https://api.telegram.org/bot${botToken.trim()}/sendMessage?chat_id=${chatId.trim()}&parse_mode=Markdown&text=${Uri.encodeComponent(message)}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        debugPrint('Telegram message sent successfully to $chatId');
      } else {
        debugPrint('Failed to send message to $chatId: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending message to Telegram ($chatId): $e');
    }
  }
}

/// Helper function to filter SMS messages.
/// ONLY allows credited/payment received SMS from Union Bank of India (UBI).
/// Strictly blocks OTPs, debit alerts, non-UBI banks, and general texts.
bool shouldForwardSms(String body, [String sender = '']) {
  final String lowerBody = body.toLowerCase();
  final String lowerSender = sender.toLowerCase();

  // 1. Blacklist (Block these): OTPs, Debit alerts, and non-credit alerts
  const List<String> blacklist = [
    'otp',
    'one time password',
    'verification code',
    'secret code',
    'debited',
    'debit',
    'withdrawn',
    'spent',
    'paid to',
    'sent to',
    'transfer to',
    'declined',
    'failed',
    'pre-approved',
    'apply now',
  ];

  for (final keyword in blacklist) {
    if (lowerBody.contains(keyword)) {
      return false;
    }
  }

  // 2. Bank Check: Must be from Union Bank of India (UBI)
  final bool isUbiSender = lowerSender.contains('ubin') ||
      lowerSender.contains('unionb') ||
      lowerSender.contains('ubi');
  final bool isUbiBody = lowerBody.contains('union bank') ||
      lowerBody.contains('union bank of india') ||
      lowerBody.contains('ubin') ||
      lowerBody.contains('ubi');

  if (!isUbiSender && !isUbiBody) {
    return false;
  }

  // 3. Credit Check: Must contain credit / received / deposited keyword
  const List<String> creditKeywords = [
    'credit',
    'credited',
    'received',
    'deposited',
  ];

  bool hasCreditKeyword = false;
  for (final keyword in creditKeywords) {
    if (lowerBody.contains(keyword)) {
      hasCreditKeyword = true;
      break;
    }
  }

  if (!hasCreditKeyword) {
    return false;
  }

  // 4. Amount Check: Must contain a currency amount indicator
  final bool hasAmount =
      RegExp(r'(?:rs\.?|inr|₹)\s*[\d,]+', caseSensitive: false).hasMatch(body);
  if (!hasAmount) {
    return false;
  }

  return true;
}

/// Handler for new SMS messages received in foreground/active state.
Future<void> onNewMessage(dynamic body, [String sender = '']) async {
  final String smsBody = body is String
      ? body
      : (body?.body as String? ?? body.toString());

  if (shouldForwardSms(smsBody, sender)) {
    final String parsedMessage = parsePaymentSms(smsBody);
    await sendToTelegram(parsedMessage);

    // Save to Transaction History
    await TransactionHistoryService.addLog(
      TransactionHistoryService.createLogFromSms(
        rawBody: smsBody,
        sender: sender,
        isForwarded: true,
        statusReason: 'Forwarded to Telegram & Soundbox',
      ),
    );

    // Announce via Voice Soundbox
    final RegExp amountRegex = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
    final RegExp senderRegex = RegExp(r'(?:received from|from)\s+([^\s,:]+)', caseSensitive: false);
    final String amount = amountRegex.firstMatch(smsBody)?.group(1) ?? '';
    final String fromSender = senderRegex.firstMatch(smsBody)?.group(1) ?? sender;

    if (amount.isNotEmpty) {
      await SoundboxService.announcePayment(
        amount: amount,
        sender: fromSender,
        bank: 'Union Bank',
      );
    }
  } else {
    debugPrint('SMS filtered out: [$sender] $smsBody');
    await TransactionHistoryService.addLog(
      TransactionHistoryService.createLogFromSms(
        rawBody: smsBody,
        sender: sender,
        isForwarded: false,
        statusReason: 'Filtered: Non-credit / OTP / Non-UBI message',
      ),
    );
  }
}

/// Handler for background SMS messages.
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(dynamic body, [String sender = '']) async {
  final String smsBody = body is String
      ? body
      : (body?.body as String? ?? body.toString());

  if (shouldForwardSms(smsBody, sender)) {
    final String parsedMessage = parsePaymentSms(smsBody);
    await sendToTelegram(parsedMessage);

    // Save to Transaction History
    await TransactionHistoryService.addLog(
      TransactionHistoryService.createLogFromSms(
        rawBody: smsBody,
        sender: sender,
        isForwarded: true,
        statusReason: 'Background Forwarded to Telegram',
      ),
    );

    // Announce via Voice Soundbox in background
    final RegExp amountRegex = RegExp(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
    final RegExp senderRegex = RegExp(r'(?:received from|from)\s+([^\s,:]+)', caseSensitive: false);
    final String amount = amountRegex.firstMatch(smsBody)?.group(1) ?? '';
    final String fromSender = senderRegex.firstMatch(smsBody)?.group(1) ?? sender;

    if (amount.isNotEmpty) {
      await SoundboxService.announcePayment(
        amount: amount,
        sender: fromSender,
        bank: 'Union Bank',
      );
    }
  } else {
    debugPrint('Background SMS filtered out: [$sender] $smsBody');
    await TransactionHistoryService.addLog(
      TransactionHistoryService.createLogFromSms(
        rawBody: smsBody,
        sender: sender,
        isForwarded: false,
        statusReason: 'Filtered: Background Non-credit SMS',
      ),
    );
  }
}

void setupSmsListener() {
  _channel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null) {
        final String sender = args['sender'] as String? ?? 'Unknown';
        final String body = args['body'] as String? ?? '';
        debugPrint('Received SMS in Flutter from $sender: $body');
        await onNewMessage(body, sender);
      }
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupSmsListener();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InyaTech',
      debugShowCheckedModeBanner: false,
      theme: IosTheme.darkTheme,
      home: const MainIosShell(),
    );
  }
}
