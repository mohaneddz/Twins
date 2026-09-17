import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/ai/chat_namer.dart';

void main() {
  group('shouldAttemptAutoName', () {
    test('is false below the message threshold', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, messageCount: autoNameThreshold - 1), isFalse);
    });

    test('is true right at the threshold for an unnamed chat', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, messageCount: autoNameThreshold), isTrue);
    });

    test('stays true past the threshold', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, messageCount: autoNameThreshold + 10), isTrue);
    });

    test('never fires once the chat already has a name, even a manual one', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: 'Movie night', messageCount: autoNameThreshold + 10), isFalse);
    });

    test('never fires twice concurrently', () {
      expect(shouldAttemptAutoName(alreadyNaming: true, chatName: null, messageCount: autoNameThreshold + 1), isFalse);
    });
  });
}
