import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_to_telegram/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UpdateService tests', () {
    test('default repo is configured properly', () async {
      final repo = await UpdateService.getGithubRepo();
      expect(repo, UpdateService.defaultRepo);

      await UpdateService.setGithubRepo('myuser/custom_repo');
      expect(await UpdateService.getGithubRepo(), 'myuser/custom_repo');
    });

    test('token can be saved and retrieved', () async {
      expect(await UpdateService.getGithubToken(), '');

      await UpdateService.setGithubToken('ghp_testtoken123');
      expect(await UpdateService.getGithubToken(), 'ghp_testtoken123');
    });
  });
}
