import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/services/soundbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Soundbox sentence generation tests', () {
    test('generates accurate Telugu announcements', () {
      final standard = SoundboxService.generateSentence(
        amount: '1000',
        sender: 'scharan1631@axl',
        bank: 'Union Bank',
        language: SoundboxService.langTelugu,
        template: SoundboxTemplate.standard,
      );
      expect(standard, contains('యూనియన్ బ్యాంక్ లో 1000 రూపాయలు క్రెడిట్ అయ్యాయి'));

      final short = SoundboxService.generateSentence(
        amount: '500',
        language: SoundboxService.langTelugu,
        template: SoundboxTemplate.short,
      );
      expect(short, contains('500 రూపాయలు రిసీవ్ అయ్యాయి'));

      final detailed = SoundboxService.generateSentence(
        amount: '2500',
        sender: 'scharan1631@axl',
        bank: 'Union Bank',
        language: SoundboxService.langTelugu,
        template: SoundboxTemplate.detailed,
      );
      expect(detailed, contains('scharan1631 నుండి 2500 రూపాయలు యూనియన్ బ్యాంక్ లో క్రెడిట్ అయ్యాయి'));
    });

    test('generates accurate English announcements', () {
      final standard = SoundboxService.generateSentence(
        amount: '1000',
        sender: 'Ramesh',
        bank: 'Union Bank',
        language: SoundboxService.langEnglishIndia,
        template: SoundboxTemplate.standard,
      );
      expect(standard, contains('Received Rupees 1000 on Union Bank'));

      final detailed = SoundboxService.generateSentence(
        amount: '1500',
        sender: 'Ramesh@upi',
        bank: 'Union Bank',
        language: SoundboxService.langEnglishIndia,
        template: SoundboxTemplate.detailed,
      );
      expect(detailed, contains('Received Rupees 1500 from Ramesh on Union Bank'));
    });

    test('generates accurate Hindi announcements', () {
      final standard = SoundboxService.generateSentence(
        amount: '1000',
        language: SoundboxService.langHindi,
        template: SoundboxTemplate.standard,
      );
      expect(standard, contains('यूनियन बैंक में 1000 रुपये प्राप्त हुए'));
    });
  });

  group('SoundboxService preferences tests', () {
    test('reads and persists settings correctly', () async {
      expect(await SoundboxService.isEnabled(), isTrue);
      expect(await SoundboxService.getLanguage(), SoundboxService.langTelugu);
      expect(await SoundboxService.getSpeechRate(), 0.5);

      await SoundboxService.setEnabled(false);
      expect(await SoundboxService.isEnabled(), isFalse);

      await SoundboxService.setLanguage(SoundboxService.langEnglishIndia);
      expect(await SoundboxService.getLanguage(), SoundboxService.langEnglishIndia);

      await SoundboxService.setSpeechRate(0.6);
      expect(await SoundboxService.getSpeechRate(), 0.6);

      await SoundboxService.setTemplate(SoundboxTemplate.short);
      expect(await SoundboxService.getTemplate(), SoundboxTemplate.short);
    });
  });
}
