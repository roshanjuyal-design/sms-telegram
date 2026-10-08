import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundboxTemplate {
  standard,
  short,
  detailed,
}

class SoundboxService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static const String keyEnabled = 'soundbox_enabled';
  static const String keyLanguage = 'soundbox_language';
  static const String keySpeechRate = 'soundbox_speech_rate';
  static const String keyPitch = 'soundbox_pitch';
  static const String keyVolume = 'soundbox_volume';
  static const String keyTemplate = 'soundbox_template';

  static const String langTelugu = 'te-IN';
  static const String langEnglishIndia = 'en-IN';
  static const String langHindi = 'hi-IN';
  static const String langEnglishUS = 'en-US';

  /// Initialize TTS engine with recommended configurations
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setLanguage(langTelugu);
      await _flutterTts.awaitSpeakCompletion(true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  // --- Preferences Getters & Setters ---

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyEnabled, value);
    } catch (e) {
      debugPrint('Error saving soundbox enabled: $e');
    }
  }

  static Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyLanguage) ?? langTelugu;
    } catch (_) {
      return langTelugu;
    }
  }

  static Future<void> setLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLanguage, lang);
    } catch (e) {
      debugPrint('Error saving soundbox language: $e');
    }
  }

  static Future<double> getSpeechRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(keySpeechRate) ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setSpeechRate(double rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keySpeechRate, rate);
    } catch (e) {
      debugPrint('Error saving speech rate: $e');
    }
  }

  static Future<double> getPitch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(keyPitch) ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  static Future<void> setPitch(double pitch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keyPitch, pitch);
    } catch (e) {
      debugPrint('Error saving pitch: $e');
    }
  }

  static Future<double> getVolume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(keyVolume) ?? 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  static Future<void> setVolume(double volume) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(keyVolume, volume);
    } catch (e) {
      debugPrint('Error saving volume: $e');
    }
  }

  static Future<SoundboxTemplate> getTemplate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(keyTemplate) ?? 'standard';
      switch (str) {
        case 'short':
          return SoundboxTemplate.short;
        case 'detailed':
          return SoundboxTemplate.detailed;
        default:
          return SoundboxTemplate.standard;
      }
    } catch (_) {
      return SoundboxTemplate.standard;
    }
  }

  static Future<void> setTemplate(SoundboxTemplate template) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyTemplate, template.name);
    } catch (e) {
      debugPrint('Error saving soundbox template: $e');
    }
  }

  // --- Sentence Generation ---

  static String generateSentence({
    required String amount,
    String sender = '',
    String bank = 'Union Bank',
    required String language,
    required SoundboxTemplate template,
  }) {
    // Normalize amount formatting
    final cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '').trim();
    final displayAmount = cleanAmount.isNotEmpty ? cleanAmount : amount;

    // Filter sender name to readable words if email or upi id (e.g. scharan1631@axl -> scharan)
    String cleanSender = sender.trim();
    if (cleanSender.contains('@')) {
      cleanSender = cleanSender.split('@').first;
    }

    if (language == langTelugu) {
      switch (template) {
        case SoundboxTemplate.short:
          return '$displayAmount రూపాయలు రిసీవ్ అయ్యాయి';
        case SoundboxTemplate.detailed:
          if (cleanSender.isNotEmpty) {
            return '$cleanSender నుండి $displayAmount రూపాయలు యూనియన్ బ్యాంక్ లో క్రెడిట్ అయ్యాయి';
          }
          return 'యూనియన్ బ్యాంక్ లో $displayAmount రూపాయలు క్రెడిట్ అయ్యాయి';
        case SoundboxTemplate.standard:
          return 'యూనియన్ బ్యాంక్ లో $displayAmount రూపాయలు క్రెడిట్ అయ్యాయి';
      }
    } else if (language == langHindi) {
      switch (template) {
        case SoundboxTemplate.short:
          return '$displayAmount रुपये प्राप्त हुए';
        case SoundboxTemplate.detailed:
          if (cleanSender.isNotEmpty) {
            return '$cleanSender से $displayAmount रुपये यूनियन बैंक में प्राप्त हुए';
          }
          return 'यूनियन बैंक में $displayAmount रुपये प्राप्त हुए';
        case SoundboxTemplate.standard:
          return 'यूनियन बैंक में $displayAmount रुपये प्राप्त हुए';
      }
    } else {
      // English (India / US)
      switch (template) {
        case SoundboxTemplate.short:
          return 'Received Rupees $displayAmount';
        case SoundboxTemplate.detailed:
          if (cleanSender.isNotEmpty) {
            return 'Received Rupees $displayAmount from $cleanSender on Union Bank';
          }
          return 'Received Rupees $displayAmount on Union Bank';
        case SoundboxTemplate.standard:
          return 'Received Rupees $displayAmount on Union Bank';
      }
    }
  }

  /// Announce incoming payment loudly via TTS soundbox
  static Future<void> announcePayment({
    required String amount,
    String sender = '',
    String bank = 'Union Bank',
  }) async {
    final enabled = await isEnabled();
    if (!enabled) return;

    await init();

    final language = await getLanguage();
    final rate = await getSpeechRate();
    final pitch = await getPitch();
    final volume = await getVolume();
    final template = await getTemplate();

    final text = generateSentence(
      amount: amount,
      sender: sender,
      bank: bank,
      language: language,
      template: template,
    );

    try {
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);

      await _flutterTts.speak(text);
      debugPrint('Soundbox announced: "$text" in $language');
    } catch (e) {
      debugPrint('Error speaking in Soundbox: $e');
    }
  }

  /// Loud warning announcement when a duplicate/fraud transaction is detected
  static Future<void> announceDuplicate({required String amount}) async {
    final enabled = await isEnabled();
    if (!enabled) return;

    await init();

    final language = await getLanguage();
    String alertText;

    if (language == langTelugu) {
      alertText = 'హెచ్చరిక! ఈ లావాదేవీ నెంబర్ ఇంతకుముందే జమ అయ్యింది! డూప్లికేట్ పేమెంట్!';
    } else if (language == langHindi) {
      alertText = 'चेतावनी! यह ट्रांजेक्शन नंबर पहले ही प्राप्त हो चुका है! डुप्लीकेट पेमेंट!';
    } else {
      alertText = 'Warning! Duplicate transaction detected! This payment reference was already received earlier!';
    }

    try {
      await _flutterTts.stop();
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setLanguage(language);
      await _flutterTts.speak(alertText);
      debugPrint('Soundbox duplicate alert announced: "$alertText"');
    } catch (e) {
      debugPrint('Error speaking duplicate alert in Soundbox: $e');
    }
  }

  /// Test current Soundbox configuration with a sample announcement
  static Future<void> testAnnouncement({
    String? customLanguage,
    double? customRate,
    double? customPitch,
    double? customVolume,
    SoundboxTemplate? customTemplate,
  }) async {
    await init();

    final language = customLanguage ?? await getLanguage();
    final rate = customRate ?? await getSpeechRate();
    final pitch = customPitch ?? await getPitch();
    final volume = customVolume ?? await getVolume();
    final template = customTemplate ?? await getTemplate();

    final text = generateSentence(
      amount: '1000',
      sender: 'Roshan',
      bank: 'Union Bank',
      language: language,
      template: template,
    );

    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(language);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);

      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error in test announcement: $e');
    }
  }

  /// Stop any ongoing speech
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
