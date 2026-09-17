import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twins/sharing/share_intent_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('pending share replay', () {
    test('consuming with nothing stashed returns null', () async {
      expect(await ShareIntentService.instance.consumePendingShare(), isNull);
    });

    test('stashing then consuming returns the same text', () async {
      await ShareIntentService.instance.stashPendingShare('https://youtu.be/abc123');
      expect(await ShareIntentService.instance.consumePendingShare(), 'https://youtu.be/abc123');
    });

    test('consuming clears the stash so a share never replays twice', () async {
      await ShareIntentService.instance.stashPendingShare('https://example.com');
      await ShareIntentService.instance.consumePendingShare();
      expect(await ShareIntentService.instance.consumePendingShare(), isNull);
    });

    test('a later stash overwrites an earlier, unconsumed one', () async {
      await ShareIntentService.instance.stashPendingShare('https://first.example.com');
      await ShareIntentService.instance.stashPendingShare('https://second.example.com');
      expect(await ShareIntentService.instance.consumePendingShare(), 'https://second.example.com');
    });
  });
}
