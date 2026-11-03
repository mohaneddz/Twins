import 'package:flutter_test/flutter_test.dart';
import 'package:twins/features/chat/chat_commands.dart';

void main() {
  test('reads a command and its text', () {
    final parsed = parseCommand('/plan movie night fri 8pm')!;
    expect(parsed.command, ChatCommand.plan);
    expect(parsed.argument, 'movie night fri 8pm');
    final plan = parsed.plan(now: DateTime(2026, 11, 3, 14))!;
    expect(plan.title, 'Movie night');
    expect(plan.startsAt, DateTime(2026, 11, 6, 20));
  });

  test('commands are case-insensitive and may stand alone', () {
    expect(parseCommand('/TODAY')!.command, ChatCommand.today);
    expect(parseCommand('/plan')!.argument, '');
  });

  test('plain text and unknown commands are not commands', () {
    expect(parseCommand('hey /plan'), isNull);
    expect(parseCommand('/shrug'), isNull);
  });

  test('suggestions narrow as you type and stop at a space', () {
    expect(suggestCommands('/'), ChatCommand.values);
    expect(suggestCommands('/t'), [ChatCommand.today, ChatCommand.tomorrow]);
    expect(suggestCommands('/plan '), isEmpty);
    expect(suggestCommands('/plan'), isEmpty);
  });
}
