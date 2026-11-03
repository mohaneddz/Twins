import '../../utils/when_parser.dart';

/// Slash commands typed in a chat composer. Plans made here land on the
/// shared calendar and show up in the chat as a card.
enum ChatCommand {
  plan('plan', 'movie night fri 8pm', 'Put a plan on our calendar'),
  remind('remind', 'call grandma sun 6pm', 'A reminder right when it happens'),
  today('today', '', "Today's plans"),
  tomorrow('tomorrow', '', "Tomorrow's plans"),
  week('week', '', 'The next 7 days'),
  next('next', '', 'Our next plan'),
  cancel('cancel', '', 'Call off a plan'),
  help('help', '', 'What all of these do');

  final String name;

  /// Shown greyed after the command while typing, and in /help.
  final String example;
  final String description;
  const ChatCommand(this.name, this.example, this.description);

  bool get takesText => example.isNotEmpty;
}

class ParsedCommand {
  final ChatCommand command;
  final String argument;
  const ParsedCommand(this.command, this.argument);

  /// For /plan and /remind: what the text says, or null when it doesn't
  /// say when yet.
  ParsedPlan? plan({DateTime? now}) => command.takesText ? parsePlan(argument, now: now) : null;
}

/// The command [text] starts with, if any. "/plan" with nothing after it
/// still counts, so the composer can show the example.
ParsedCommand? parseCommand(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('/')) return null;
  final space = trimmed.indexOf(RegExp(r'\s'));
  final name = (space == -1 ? trimmed.substring(1) : trimmed.substring(1, space)).toLowerCase();
  for (final command in ChatCommand.values) {
    if (command.name == name) {
      return ParsedCommand(command, space == -1 ? '' : trimmed.substring(space).trim());
    }
  }
  return null;
}

/// Commands to suggest while "/pl" is being typed (all of them for "/").
List<ChatCommand> suggestCommands(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('/') || trimmed.contains(RegExp(r'\s'))) return const [];
  final typed = trimmed.substring(1).toLowerCase();
  return ChatCommand.values.where((c) => c.name.startsWith(typed) && c.name != typed).toList();
}
