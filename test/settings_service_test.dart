import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/models/telegram_recipient.dart';
import 'package:sms_to_telegram/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TelegramRecipient tests', () {
    test('serializes and deserializes correctly', () {
      const recipient = TelegramRecipient(
        id: 'test_1',
        name: 'Shop Cashier',
        chatId: '123456789',
        isEnabled: true,
      );

      final map = recipient.toMap();
      final fromMap = TelegramRecipient.fromMap(map);

      expect(fromMap.id, recipient.id);
      expect(fromMap.name, recipient.name);
      expect(fromMap.chatId, recipient.chatId);
      expect(fromMap.isEnabled, recipient.isEnabled);
    });

    test('copyWith works correctly', () {
      const recipient = TelegramRecipient(
        id: 'test_1',
        name: 'Agent',
        chatId: '12345',
        isEnabled: true,
      );

      final updated = recipient.copyWith(name: 'Super Agent', isEnabled: false);
      expect(updated.name, 'Super Agent');
      expect(updated.isEnabled, false);
      expect(updated.chatId, '12345');
    });
  });

  group('SettingsService tests', () {
    test('returns default Bot Token when none is set', () async {
      final token = await SettingsService.getBotToken();
      expect(token, SettingsService.defaultBotToken);
    });

    test('saves and retrieves custom Bot Token', () async {
      await SettingsService.setBotToken('123456:CUSTOM_TOKEN');
      final token = await SettingsService.getBotToken();
      expect(token, '123456:CUSTOM_TOKEN');
    });

    test('returns default recipients initially', () async {
      final recipients = await SettingsService.getRecipients();
      expect(recipients.length, 2);
      expect(recipients[0].name, 'Agent 1 (Primary)');
    });

    test('adds, toggles, updates and deletes recipients', () async {
      const newRecipient = TelegramRecipient(
        id: 'agent_3',
        name: 'Agent 3',
        chatId: '987654321',
        isEnabled: true,
      );

      await SettingsService.addRecipient(newRecipient);
      var list = await SettingsService.getRecipients();
      expect(list.length, 3);
      expect(list.any((r) => r.id == 'agent_3'), isTrue);

      // Toggle
      await SettingsService.toggleRecipient('agent_3', false);
      var activeChatIds = await SettingsService.getActiveChatIds();
      expect(activeChatIds.contains('987654321'), isFalse);

      // Update
      await SettingsService.updateRecipient(
        const TelegramRecipient(
          id: 'agent_3',
          name: 'Manager',
          chatId: '987654321',
          isEnabled: true,
        ),
      );
      list = await SettingsService.getRecipients();
      final updated = list.firstWhere((r) => r.id == 'agent_3');
      expect(updated.name, 'Manager');
      expect(updated.isEnabled, true);

      // Delete
      await SettingsService.deleteRecipient('agent_3');
      list = await SettingsService.getRecipients();
      expect(list.length, 2);
    });

    test('resetToDefaults clears stored values', () async {
      await SettingsService.setBotToken('TEMP_TOKEN');
      await SettingsService.resetToDefaults();
      final token = await SettingsService.getBotToken();
      expect(token, SettingsService.defaultBotToken);
    });
  });
}
