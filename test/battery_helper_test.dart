import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/services/battery_helper_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.example.sms_to_telegram/sms');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isIgnoringBatteryOptimizations':
          return true;
        case 'getDeviceInfo':
          return {
            'manufacturer': 'Xiaomi',
            'model': 'Redmi Note 12',
            'brand': 'Redmi',
            'sdkVersion': 33,
          };
        case 'getBatteryInfo':
          return {
            'batteryLevel': 85,
            'isCharging': true,
          };
        case 'openAutoStartSettings':
          return true;
        case 'openAppDetails':
          return true;
        case 'requestIgnoreBatteryOptimizations':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    BatteryHelperService.stopHeartbeatTimer();
  });

  group('BatteryHelperService tests', () {
    test('checks battery optimization status', () async {
      final isIgnored = await BatteryHelperService.isIgnoringBatteryOptimizations();
      expect(isIgnored, isTrue);
    });

    test('fetches device info accurately', () async {
      final devInfo = await BatteryHelperService.getDeviceInfo();
      expect(devInfo['manufacturer'], 'Xiaomi');
      expect(devInfo['model'], 'Redmi Note 12');
    });

    test('fetches battery metrics accurately', () async {
      final battInfo = await BatteryHelperService.getBatteryInfo();
      expect(battInfo['batteryLevel'], 85);
      expect(battInfo['isCharging'], isTrue);
    });

    test('persists heartbeat configuration settings', () async {
      expect(await BatteryHelperService.isHeartbeatEnabled(), isFalse);
      expect(await BatteryHelperService.getHeartbeatIntervalHours(), 12);

      await BatteryHelperService.setHeartbeatEnabled(true);
      expect(await BatteryHelperService.isHeartbeatEnabled(), isTrue);

      await BatteryHelperService.setHeartbeatIntervalHours(6);
      expect(await BatteryHelperService.getHeartbeatIntervalHours(), 6);
    });
  });
}
