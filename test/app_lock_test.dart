import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/services/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppLockService tests', () {
    test('defaults to lock enabled with default PIN 5440', () async {
      expect(await AppLockService.isLockEnabled(), isTrue);
      expect(await AppLockService.getPin(), '5440');
      expect(await AppLockService.verifyPin('5440'), isTrue);
      expect(await AppLockService.verifyPin('1234'), isFalse);
    });

    test('can toggle lock enabled and biometrics', () async {
      await AppLockService.setLockEnabled(false);
      expect(await AppLockService.isLockEnabled(), isFalse);

      await AppLockService.setLockEnabled(true);
      expect(await AppLockService.isLockEnabled(), isTrue);

      expect(await AppLockService.isBiometricsEnabled(), isTrue);
      await AppLockService.setBiometricsEnabled(false);
      expect(await AppLockService.isBiometricsEnabled(), isFalse);
    });

    test('validates and updates 4-digit PIN', () async {
      // Invalid pins rejected
      expect(await AppLockService.setPin('123'), isFalse); // too short
      expect(await AppLockService.setPin('12345'), isFalse); // too long
      expect(await AppLockService.setPin('abcd'), isFalse); // non-numeric

      // Valid pin accepted
      expect(await AppLockService.setPin('9876'), isTrue);
      expect(await AppLockService.getPin(), '9876');
      expect(await AppLockService.verifyPin('9876'), isTrue);
      expect(await AppLockService.verifyPin('5440'), isFalse);
    });
  });
}
