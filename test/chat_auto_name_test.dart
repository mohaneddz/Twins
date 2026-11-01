import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/ai/chat_namer.dart';

void main() {
  group('shouldAttemptAutoName', () {
    test('is false below the message threshold', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, threshold: 3, messageCount: 2), isFalse);
    });

    test('is true right at the threshold for an unnamed chat', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, threshold: 3, messageCount: 3), isTrue);
    });

    test('stays true past the threshold', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, threshold: 3, messageCount: 13), isTrue);
    });

    test('never fires once the chat already has a name, even a manual one', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: 'Movie night', threshold: 3, messageCount: 13), isFalse);
    });

    test('never fires twice concurrently', () {
      expect(shouldAttemptAutoName(alreadyNaming: true, chatName: null, threshold: 3, messageCount: 4), isFalse);
    });

    test('with a threshold of 1 the first message names the chat', () {
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, threshold: 1, messageCount: 1), isTrue);
      expect(shouldAttemptAutoName(alreadyNaming: false, chatName: null, threshold: 1, messageCount: 0), isFalse);
    });
  });
}
