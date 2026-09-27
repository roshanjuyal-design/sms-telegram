import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telegram_recipient.dart';

class SettingsService {
  static const String keyBotToken = 'telegram_bot_token';
  static const String keyRecipients = 'telegram_recipients';

  static const String defaultBotToken =
      '8814275955:AAF6QXMd26V3f8_-S8x08xV6dkFlAuVKsNQ';

  static final List<TelegramRecipient> defaultRecipients = [
    const TelegramRecipient(
      id: 'agent_1',
      name: 'Agent 1 (Primary)',
      chatId: '616463263',
      isEnabled: true,
    ),
    const TelegramRecipient(
      id: 'agent_2',
      name: 'Agent 2',
      chatId: '8976081182',
      isEnabled: true,
    ),
  ];

  /// Get saved Bot Token or return default
  static Future<String> getBotToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(keyBotToken);
      if (token != null && token.trim().isNotEmpty) {
        return token.trim();
      }
    } catch (e) {
      debugPrint('Error loading bot token: $e');
    }
    return defaultBotToken;
  }

  /// Save Bot Token
  static Future<bool> setBotToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(keyBotToken, token.trim());
    } catch (e) {
      debugPrint('Error saving bot token: $e');
      return false;
    }
  }

  /// Get list of all saved Telegram recipients
  static Future<List<TelegramRecipient>> getRecipients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recipientsJson = prefs.getString(keyRecipients);
      if (recipientsJson != null && recipientsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(recipientsJson) as List<dynamic>;
        return decoded
            .map((item) => TelegramRecipient.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading recipients: $e');
    }
    return List.from(defaultRecipients);
  }

  /// Save full list of recipients
  static Future<bool> saveRecipients(List<TelegramRecipient> recipients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> maps =
          recipients.map((r) => r.toMap()).toList();
      return await prefs.setString(keyRecipients, json.encode(maps));
    } catch (e) {
      debugPrint('Error saving recipients: $e');
      return false;
    }
  }

  /// Save or update a single recipient
  static Future<void> saveRecipient(TelegramRecipient recipient) async {
    final list = await getRecipients();
    final index = list.indexWhere((r) => r.id == recipient.id);
    if (index != -1) {
      list[index] = recipient;
    } else {
      list.add(recipient);
    }
    await saveRecipients(list);
  }

  /// Add a new recipient
  static Future<void> addRecipient(TelegramRecipient recipient) async {
    await saveRecipient(recipient);
  }

  /// Update an existing recipient
  static Future<void> updateRecipient(TelegramRecipient updated) async {
    await saveRecipient(updated);
  }

  /// Delete a recipient by ID
  static Future<void> deleteRecipient(String id) async {
    final list = await getRecipients();
    list.removeWhere((r) => r.id == id);
    await saveRecipients(list);
  }

  /// Toggle enabled state of a recipient
  static Future<void> toggleRecipient(String id, bool isEnabled) async {
    final list = await getRecipients();
    final index = list.indexWhere((r) => r.id == id);
    if (index != -1) {
      list[index] = list[index].copyWith(isEnabled: isEnabled);
      await saveRecipients(list);
    }
  }

  /// Get only active/enabled chat IDs
  static Future<List<String>> getActiveChatIds() async {
    final list = await getRecipients();
    return list
        .where((r) => r.isEnabled && r.chatId.trim().isNotEmpty)
        .map((r) => r.chatId.trim())
        .toList();
  }

  /// Verify Bot Token with Telegram API
  static Future<Map<String, dynamic>> verifyBotToken(String token) async {
    if (token.trim().isEmpty) {
      return {'success': false, 'error': 'Bot token is empty'};
    }

    try {
      final url = Uri.parse('https://api.telegram.org/bot${token.trim()}/getMe');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['ok'] == true && data['result'] != null) {
          final result = data['result'] as Map<String, dynamic>;
          return {
            'success': true,
            'botName': result['first_name'] ?? 'Telegram Bot',
            'username': result['username'] ?? '',
            'id': result['id']?.toString() ?? '',
          };
        }
      }

      final errorBody = json.decode(response.body);
      final desc = errorBody['description'] ?? 'Invalid token or unauthorized';
      return {'success': false, 'error': desc.toString()};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  /// Send test message to a specific Chat ID
  static Future<Map<String, dynamic>> sendTestMessage({
    required String botToken,
    required String chatId,
    String? customMessage,
  }) async {
    final msg = customMessage ??
        '⚡ *InyaTech Test Message*\n\n✅ Your Telegram Chat ID is configured correctly and receiving alerts!\n\n_Sent at: ${DateTime.now().toLocal().toString().split('.').first}_';

    try {
      final url = Uri.parse(
        'https://api.telegram.org/bot${botToken.trim()}/sendMessage?chat_id=${chatId.trim()}&parse_mode=Markdown&text=${Uri.encodeComponent(msg)}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = json.decode(response.body);
        final desc = data['description'] ?? 'Failed to send message';
        return {'success': false, 'error': desc.toString()};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send test message helper returning boolean
  static Future<bool> sendTestMessageToRecipient({
    required String botToken,
    required String chatId,
  }) async {
    final result = await sendTestMessage(botToken: botToken, chatId: chatId);
    return result['success'] == true;
  }

  /// Send broadcast message to all enabled recipients
  static Future<Map<String, int>> sendBroadcastMessage({
    required String message,
  }) async {
    final botToken = await getBotToken();
    final chatIds = await getActiveChatIds();

    int successCount = 0;
    int failureCount = 0;

    if (chatIds.isEmpty || botToken.isEmpty) {
      return {'success': 0, 'failure': 0};
    }

    for (final chatId in chatIds) {
      final result = await sendTestMessage(
        botToken: botToken,
        chatId: chatId,
        customMessage: message,
      );
      if (result['success'] == true) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    return {'success': successCount, 'failure': failureCount};
  }

  /// Reset settings back to default configurations
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyBotToken);
    await prefs.remove(keyRecipients);
  }
}
