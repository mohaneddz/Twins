import 'package:flutter_test/flutter_test.dart';
import 'package:twins/data/ai/chat_namer.dart';

bool _should({
  bool alreadyNaming = false,
  String? chatName,
  bool nameIsAuto = false,
  int? namedAtCount,
  required int messageCount,
  int nameAfter = 1,
  int renameEvery = 20,
}) =>
    shouldAttemptAutoName(
      alreadyNaming: alreadyNaming,
      chatName: chatName,
      nameIsAuto: nameIsAuto,
      namedAtCount: namedAtCount,
      messageCount: messageCount,
      nameAfter: nameAfter,
      renameEvery: renameEvery,
    );

void main() {
  group('first name', () {
    test('waits for the name-after threshold', () {
      expect(_should(nameAfter: 3, messageCount: 2), isFalse);
      expect(_should(nameAfter: 3, messageCount: 3), isTrue);
    });

    test('with the default of 1 the first message names the chat', () {
      expect(_should(messageCount: 0), isFalse);
      expect(_should(messageCount: 1), isTrue);
    });

    test('never runs twice at once', () {
      expect(_should(alreadyNaming: true, messageCount: 5), isFalse);
    });
  });

  group('renaming', () {
    test('an auto name is refreshed every renameEvery messages', () {
      expect(_should(chatName: 'Plans', nameIsAuto: true, namedAtCount: 1, messageCount: 20), isFalse);
      expect(_should(chatName: 'Plans', nameIsAuto: true, namedAtCount: 1, messageCount: 21), isTrue);
    });

    test('a typed name is never replaced', () {
      expect(_should(chatName: 'Movie night', nameIsAuto: false, namedAtCount: 1, messageCount: 500), isFalse);
    });

    test('renameEvery 0 keeps the first name', () {
      expect(_should(chatName: 'Plans', nameIsAuto: true, namedAtCount: 1, messageCount: 500, renameEvery: 0), isFalse);
    });
  });
}
