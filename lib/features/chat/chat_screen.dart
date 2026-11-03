import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/ai/chat_namer.dart';
import '../../data/models/chat.dart';
import '../../data/models/event.dart';
import '../../data/models/item.dart';
import '../../data/models/message.dart';
import '../../data/models/profile.dart';
import '../../data/models/reaction.dart';
import '../../state/auth_providers.dart';
import '../../state/chat_naming_provider.dart';
import '../../state/data_providers.dart';
import '../../state/plan_reminder_provider.dart';
import '../../state/repository_provider.dart';
import '../../state/twin_color_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/item_card.dart';
import '../../widgets/reaction_bar.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';
import '../calendar/event_editor_sheet.dart';
import 'chat_commands.dart';
import 'chat_list_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _naming = false;
  bool _sending = false;

  /// The message being answered, shown above the composer.
  TwinsMessage? _replyTo;

  /// Bubbles currently built, so tapping a quote can scroll to the original.
  final _bubbleKeys = <String, GlobalKey>{};
  String? _flashId;

  @override
  void initState() {
    super.initState();
    // Command suggestions and the plan preview follow every keystroke.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startReply(TwinsMessage message) {
    HapticFeedback.selectionClick();
    setState(() => _replyTo = message);
    _focus.requestFocus();
  }

  void _jumpTo(String messageId) {
    final context = _bubbleKeys[messageId]?.currentContext;
    if (context == null) {
      showTwinsToast(this.context, "That message is further up");
      return;
    }
    Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), alignment: 0.4);
    setState(() => _flashId = messageId);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _flashId == messageId) setState(() => _flashId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    final me = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: spaceAsync.when(
          data: (space) {
            if (space == null) return const SizedBox.shrink();
            final membersAsync = ref.watch(spaceMembersProvider(space.id));
            final chatsAsync = ref.watch(chatsProvider(space.id));
            final events = ref.watch(eventsProvider(space.id)).valueOrNull ?? const <TwinsEvent>[];
            final chat = chatsAsync.valueOrNull?.firstWhere(
              (c) => c.id == widget.chatId,
              orElse: () => TwinsChat(
                id: widget.chatId,
                spaceId: space.id,
                createdBy: me?.id ?? '',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            final members = membersAsync.valueOrNull ?? const <Profile>[];
            String nameOf(String userId) => userId == me?.id
                ? 'You'
                : members.where((m) => m.id == userId).firstOrNull?.displayName ?? 'Twin';

            return Column(
              children: [
                _ChatHeader(chat: chat, onRename: chat == null ? null : () => showRenameChatSheet(context, ref, chat)),
                const Divider(height: 1),
                Expanded(
                  child: Consumer(builder: (context, ref, _) {
                    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
                    return messagesAsync.when(
                      data: (messages) {
                        if (chat != null) _maybeAutoName(chat, messages);
                        if (messages.isEmpty) {
                          // Scrollable so the empty state doesn't overflow
                          // into the composer when the keyboard is up.
                          return LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: const Center(
                                  child: EmptyState(
                                    emoji: '💬',
                                    title: 'Say hi to start the conversation',
                                    subtitle: 'Type / for commands, like /plan movie night fri 8pm',
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final byId = {for (final m in messages) m.id: m};
                        final eventsById = {for (final e in events) e.id: e};
                        // Reversed so the list starts at the newest message
                        // and stays there as attachment thumbnails load in;
                        // jumping to maxScrollExtent after the first frame
                        // landed short once images grew the content.
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(TwinsSpacing.md),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[messages.length - 1 - index];
                            final isMine = message.authorId == me?.id;
                            final original = message.replyToId == null ? null : byId[message.replyToId];
                            return _SwipeToReply(
                              key: _bubbleKeys.putIfAbsent(message.id, GlobalKey.new),
                              onReply: () => _startReply(message),
                              child: _MessageBubble(
                                message: message,
                                isMine: isMine,
                                senderLabel: nameOf(message.authorId),
                                flash: _flashId == message.id,
                                event: message.attachedEventId == null ? null : eventsById[message.attachedEventId],
                                quote: message.replyToId == null
                                    ? null
                                    : _Quote(
                                        author: original == null ? '' : nameOf(original.authorId),
                                        text: original == null ? 'Message no longer here' : _snippet(original, eventsById),
                                        color: ref.watch(colorOfUserProvider(original?.authorId)).accent,
                                        onTap: original == null ? null : () => _jumpTo(original.id),
                                      ),
                                onLongPress: () => _showMessageActions(message, space.id),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => Center(child: CircularProgressIndicator(color: context.twins.accent)),
                      error: (e, _) => const SizedBox.shrink(),
                    );
                  }),
                ),
                _composerExtras(space.id, nameOf, {for (final e in events) e.id: e}),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TwinsSpacing.md,
                    TwinsSpacing.xs,
                    TwinsSpacing.md,
                    // The Scaffold already shrinks for the keyboard; adding the
                    // inset here too counted it twice and squeezed the messages
                    // under the composer.
                    TwinsSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(PhosphorIconsBold.plus, color: context.twins.accent),
                        onPressed: () => _showAttachMenu(space.id),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Message, or / for commands'),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(space.id),
                        ),
                      ),
                      const SizedBox(width: TwinsSpacing.sm),
                      CircleAvatar(
                        backgroundColor: context.twins.accent,
                        child: IconButton(
                          icon: Icon(
                            parseCommand(_controller.text)?.command.takesText == true ? PhosphorIconsBold.calendarPlus : Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _sending ? null : () => _send(space.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: context.twins.accent)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// What sits above the composer: command suggestions, what a /plan will
  /// make, and the message being replied to.
  Widget _composerExtras(String spaceId, String Function(String) nameOf, Map<String, TwinsEvent> eventsById) {
    final palette = context.twins;
    final text = _controller.text;
    final suggestions = suggestCommands(text);
    final command = parseCommand(text);
    final children = <Widget>[];

    if (suggestions.isNotEmpty) {
      children.add(ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            for (final c in suggestions)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text.rich(TextSpan(children: [
                  TextSpan(text: '/${c.name}', style: TwinsTypography.label(context.twins.accent, size: 14)),
                  if (c.takesText) TextSpan(text: '  ${c.example}', style: TwinsTypography.body(palette.textSecondary, size: 13)),
                ])),
                subtitle: Text(c.description, style: TwinsTypography.body(palette.textSecondary, size: 12)),
                onTap: () {
                  if (c.takesText) {
                    _controller.value = TextEditingValue(
                      text: '/${c.name} ',
                      selection: TextSelection.collapsed(offset: c.name.length + 2),
                    );
                  } else {
                    _controller.clear();
                    _runCommand(spaceId, ParsedCommand(c, ''));
                  }
                },
              ),
          ],
        ),
      ));
    } else if (command != null && command.command.takesText) {
      final plan = command.plan();
      final remind = plan == null
          ? null
          : plan.reminderGiven
              ? plan.remindMinutes
              : command.command == ChatCommand.remind
                  ? 0
                  : ref.watch(planDefaultReminderProvider);
      final String line;
      if (command.argument.isEmpty) {
        line = 'Like /${command.command.name} ${command.command.example}  ·  add !30m for a reminder';
      } else if (plan == null) {
        line = 'When? Add a day or a time, like "fri 8pm" or "tomorrow"';
      } else {
        final title = plan.title.isEmpty ? (command.command == ChatCommand.remind ? 'Reminder' : 'Plan') : plan.title;
        line = '$title · ${formatPlanWhen(startsAt: plan.startsAt, endsAt: plan.endsAt, allDay: plan.allDay)} · ${formatReminder(remind)}';
      }
      children.add(_ExtraBar(
        icon: plan == null ? PhosphorIconsBold.question : PhosphorIconsBold.calendarCheck,
        color: plan == null ? palette.textSecondary : context.twins.accent,
        text: line,
      ));
    }

    final replyTo = _replyTo;
    if (replyTo != null) {
      children.add(_ExtraBar(
        icon: PhosphorIconsBold.arrowBendUpLeft,
        color: context.twins.accent,
        label: 'Replying to ${nameOf(replyTo.authorId) == 'You' ? 'yourself' : nameOf(replyTo.authorId)}',
        text: _snippet(replyTo, eventsById),
        onClose: () => setState(() => _replyTo = null),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  String _snippet(TwinsMessage message, Map<String, TwinsEvent> eventsById) {
    if (message.body.isNotEmpty) return message.body;
    final event = message.attachedEventId == null ? null : eventsById[message.attachedEventId];
    if (event != null) return '📅 ${event.title}';
    if (message.attachedItemId != null) return '📎 Saved item';
    return '';
  }

  Future<void> _maybeAutoName(TwinsChat chat, List<TwinsMessage> messages) async {
    final shouldName = shouldAttemptAutoName(
      alreadyNaming: _naming,
      chatName: chat.name,
      nameIsAuto: chat.nameIsAuto,
      namedAtCount: chat.namedAtCount,
      messageCount: messages.length,
      nameAfter: ref.read(chatAutoNameAfterProvider),
      renameEvery: ref.read(chatRenameEveryProvider),
    );
    if (!shouldName) return;
    _naming = true;
    // The latest stretch of the conversation, so a rename follows where the
    // chat went rather than how it started.
    final recent = messages.skip(messages.length > 30 ? messages.length - 30 : 0);
    final name = await suggestChatName(recent.map((m) => m.body).where((b) => b.isNotEmpty).toList());
    if (name != null && mounted) {
      await ref.read(repositoryProvider).autoNameChat(chat.id, name, messageCount: messages.length);
    }
    _naming = false;
  }

  Future<void> _send(String spaceId) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final command = parseCommand(text);
    if (command != null) {
      await _runCommand(spaceId, command);
      return;
    }
    if (RegExp(r'^/\w+$').hasMatch(text)) {
      showTwinsToast(context, 'No $text command. Type / to see them all');
      return;
    }
    final replyTo = _replyTo?.id;
    _controller.clear();
    setState(() => _replyTo = null);
    await ref.read(repositoryProvider).sendMessage(spaceId: spaceId, chatId: widget.chatId, body: text, replyToId: replyTo);
  }

  Future<void> _runCommand(String spaceId, ParsedCommand command) async {
    switch (command.command) {
      case ChatCommand.plan:
      case ChatCommand.remind:
        await _makePlan(spaceId, command);
      case ChatCommand.today:
        _controller.clear();
        final today = DateUtils.dateOnly(DateTime.now());
        await _showPlans(spaceId, 'Today', (e) => e.occursOn(today));
      case ChatCommand.tomorrow:
        _controller.clear();
        final tomorrow = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
        await _showPlans(spaceId, 'Tomorrow', (e) => e.occursOn(tomorrow));
      case ChatCommand.week:
        _controller.clear();
        final end = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
        await _showPlans(spaceId, 'The next 7 days', (e) => e.startsAt.isBefore(end));
      case ChatCommand.next:
        _controller.clear();
        await _showPlans(spaceId, 'Next up', (_) => true, limit: 1);
      case ChatCommand.cancel:
        _controller.clear();
        await _cancelPlan(spaceId);
      case ChatCommand.help:
        _controller.clear();
        await _showHelp();
    }
  }

  Future<void> _makePlan(String spaceId, ParsedCommand command) async {
    final isReminder = command.command == ChatCommand.remind;
    if (command.argument.isEmpty) {
      showTwinsToast(context, 'Add what and when, like /${command.command.name} ${command.command.example}');
      return;
    }
    final plan = command.plan();
    if (plan == null) {
      showTwinsToast(context, 'When? Add a day or time, like "fri 8pm"', isError: true);
      return;
    }
    final remind = plan.reminderGiven ? plan.remindMinutes : (isReminder ? 0 : ref.read(planDefaultReminderProvider));
    final replyTo = _replyTo?.id;
    setState(() => _sending = true);
    final repo = ref.read(repositoryProvider);
    try {
      final event = await repo.createEvent(
        spaceId: spaceId,
        title: plan.title.isEmpty ? (isReminder ? 'Reminder' : 'Plan') : plan.title,
        startsAt: plan.startsAt,
        endsAt: plan.endsAt,
        allDay: plan.allDay,
        remindMinutes: remind,
        chatId: widget.chatId,
      );
      _controller.clear();
      setState(() => _replyTo = null);
      await repo.sendMessage(spaceId: spaceId, chatId: widget.chatId, body: '', attachedEventId: event.id, replyToId: replyTo);
    } catch (_) {
      if (mounted) showTwinsToast(context, "Couldn't save the plan", isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<TwinsEvent> _upcoming(String spaceId) => ref.read(upcomingEventsProvider(spaceId));

  Future<void> _showPlans(String spaceId, String title, bool Function(TwinsEvent) where, {int? limit}) {
    var plans = _upcoming(spaceId).where(where).toList();
    if (limit != null) plans = plans.take(limit).toList();
    return showTwinsBottomSheet<void>(
      context: context,
      title: title,
      child: plans.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.lg),
              child: Text('Nothing planned. Try /plan', textAlign: TextAlign.center, style: TwinsTypography.body(context.twins.textSecondary)),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final event in plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
                      child: EventCard(
                        event: event,
                        accent: planAccent(ref, event),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/event/${event.id}');
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _cancelPlan(String spaceId) async {
    final plans = _upcoming(spaceId);
    final picked = await showTwinsBottomSheet<TwinsEvent>(
      context: context,
      title: 'Call off which plan?',
      child: plans.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.lg),
              child: Text('Nothing planned to call off', textAlign: TextAlign.center, style: TwinsTypography.body(context.twins.textSecondary)),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final event in plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
                      child: EventCard(event: event, accent: planAccent(ref, event), onTap: () => Navigator.of(context).pop(event)),
                    ),
                ],
              ),
            ),
    );
    if (picked == null || !mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Call off "${picked.title}"?',
      message: 'Your twin gets told, and the reminder is dropped on both phones.',
      confirmLabel: 'Call it off',
    );
    if (ok) await ref.read(repositoryProvider).cancelEvent(picked.id);
  }

  Future<void> _showHelp() {
    final palette = context.twins;
    return showTwinsBottomSheet<void>(
      context: context,
      title: 'Chat commands',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in ChatCommand.values)
            Padding(
              padding: const EdgeInsets.only(bottom: TwinsSpacing.sm),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '/${c.name}', style: TwinsTypography.label(context.twins.accent, size: 14)),
                if (c.takesText) TextSpan(text: ' ${c.example}', style: TwinsTypography.body(palette.textSecondary, size: 13)),
                TextSpan(text: '\n${c.description}', style: TwinsTypography.body(palette.textPrimary, size: 13.5)),
              ])),
            ),
          const SizedBox(height: TwinsSpacing.xs),
          Text(
            'Plans understand days (fri, tomorrow, 12/11, nov 20), times (8pm, 20:30, at 8), '
            'ranges (8-11pm) and "in 2 hours". Add !30m, !1h or !1d for a reminder, or !no for none.',
            style: TwinsTypography.body(palette.textSecondary, size: 12.5),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessageActions(TwinsMessage message, String spaceId) async {
    final action = await showTwinsBottomSheet<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final emoji in quickReactions)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop('react:$emoji'),
                  child: Text(emoji, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
          const SizedBox(height: TwinsSpacing.sm),
          ListTile(
            leading: const Icon(PhosphorIconsBold.arrowBendUpLeft),
            title: const Text('Reply'),
            onTap: () => Navigator.of(context).pop('reply'),
          ),
          if (message.body.isNotEmpty) ...[
            ListTile(
              leading: const Icon(PhosphorIconsBold.copy),
              title: const Text('Copy text'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.calendarPlus),
              title: const Text('Make it a plan'),
              onTap: () => Navigator.of(context).pop('plan'),
            ),
          ],
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('react:')) {
      await ref.read(repositoryProvider).toggleReaction(
            spaceId: message.spaceId,
            targetType: ReactionTargetType.message,
            targetId: message.id,
            emoji: action.substring(6),
          );
    } else if (action == 'reply') {
      _startReply(message);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.body));
      if (mounted) showTwinsToast(context, 'Copied');
    } else if (action == 'plan') {
      final title = message.body.length > 80 ? message.body.substring(0, 80) : message.body;
      final event = await showEventEditor(context, spaceId: spaceId, chatId: widget.chatId, initialTitle: title);
      if (event != null) {
        await ref.read(repositoryProvider).sendMessage(
              spaceId: spaceId,
              chatId: widget.chatId,
              body: '',
              attachedEventId: event.id,
              replyToId: message.id,
            );
      }
    }
  }

  Future<void> _showAttachMenu(String spaceId) async {
    final choice = await showTwinsBottomSheet<_AttachChoice>(
      context: context,
      title: 'Share to chat',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(PhosphorIconsBold.calendarPlus, color: context.twins.accent),
            title: const Text('A plan'),
            subtitle: const Text('Put something on our calendar'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.plan),
          ),
          ListTile(
            leading: Icon(PhosphorIconsBold.plusCircle, color: context.twins.accent),
            title: const Text('New item'),
            subtitle: const Text('Save a link, photo, file, or note'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.newItem),
          ),
          ListTile(
            leading: Icon(PhosphorIconsBold.stack, color: context.twins.accent),
            title: const Text('Existing item'),
            subtitle: const Text('Point to something already saved'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.existingItem),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachChoice.plan:
        final event = await showEventEditor(context, spaceId: spaceId, chatId: widget.chatId);
        if (event != null) {
          final replyTo = _replyTo?.id;
          setState(() => _replyTo = null);
          await ref.read(repositoryProvider).sendMessage(
                spaceId: spaceId,
                chatId: widget.chatId,
                body: '',
                attachedEventId: event.id,
                replyToId: replyTo,
              );
        }
      case _AttachChoice.newItem:
        context.push('/add');
      case _AttachChoice.existingItem:
        final item = await _pickExistingItem(spaceId);
        if (item != null) await _sendAttachment(spaceId, item);
    }
  }

  Future<TwinsItem?> _pickExistingItem(String spaceId) {
    return showTwinsBottomSheet<TwinsItem>(
      context: context,
      title: 'Attach an item',
      child: SizedBox(
        height: 420,
        child: Consumer(builder: (context, ref, _) {
          final itemsAsync = ref.watch(allItemsProvider(spaceId));
          return itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(emoji: '📭', title: 'Nothing saved yet');
              }
              return GridView.builder(
                padding: const EdgeInsets.only(top: TwinsSpacing.xs),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: TwinsSpacing.sm,
                  mainAxisSpacing: TwinsSpacing.sm,
                  childAspectRatio: 0.78,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ItemCard(item: item, onTap: () => Navigator.of(context).pop(item));
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: context.twins.accent)),
            error: (e, _) => const EmptyState(emoji: '⚠️', title: "Couldn't load items"),
          );
        }),
      ),
    );
  }

  /// The card already shows the item's title, so the message text is only
  /// whatever was typed in the composer.
  Future<void> _sendAttachment(String spaceId, TwinsItem item) async {
    final text = _controller.text.trim();
    final replyTo = _replyTo?.id;
    _controller.clear();
    setState(() => _replyTo = null);
    await ref.read(repositoryProvider).sendMessage(
          spaceId: spaceId,
          chatId: widget.chatId,
          body: text,
          attachedItemId: item.id,
          replyToId: replyTo,
        );
  }
}

enum _AttachChoice { plan, newItem, existingItem }

/// A strip above the composer: a reply preview or what a command will do.
class _ExtraBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final String text;
  final VoidCallback? onClose;

  const _ExtraBar({required this.icon, required this.color, this.label, required this.text, this.onClose});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TwinsSpacing.md, TwinsSpacing.xs, TwinsSpacing.xs, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: TwinsSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) Text(label!, style: TwinsTypography.label(color, size: 12)),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TwinsTypography.body(palette.textSecondary, size: 13)),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'Cancel reply',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// The answered message, inside a reply's bubble.
class _Quote extends StatelessWidget {
  final String author;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _Quote({required this.author, required this.text, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: TwinsColors.navy.withValues(alpha: 0.06),
          borderRadius: TwinsRadius.smRadius,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (author.isNotEmpty) Text(author, style: TwinsTypography.label(color, size: 11.5)),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TwinsTypography.body(TwinsColors.navy.withValues(alpha: 0.7), size: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag a message to the right to answer it.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeToReply({super.key, required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const _trigger = 56.0;
  double _dx = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (details) {
        final next = (_dx + details.delta.dx).clamp(0.0, 80.0);
        if (_dx < _trigger && next >= _trigger) HapticFeedback.selectionClick();
        setState(() => _dx = next);
      },
      onHorizontalDragEnd: (_) {
        if (_dx >= _trigger) widget.onReply();
        setState(() {
          _dx = 0;
          _dragging = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: progress,
            child: Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(PhosphorIconsBold.arrowBendUpLeft, size: 20, color: context.twins.accent),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final TwinsMessage message;
  final bool isMine;
  final String senderLabel;
  final Widget? quote;
  final TwinsEvent? event;
  final bool flash;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderLabel,
    required this.onLongPress,
    this.quote,
    this.event,
    this.flash = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(
      reactionsProvider(ReactionQuery(message.spaceId, ReactionTargetType.message, message.id)),
    );
    final reactions = reactionsAsync.valueOrNull ?? const [];
    final event = this.event;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: flash ? context.twins.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: TwinsRadius.mdRadius,
      ),
      child: ChatBubble(
        body: message.body,
        createdAt: message.createdAt,
        isMine: isMine,
        senderLabel: senderLabel,
        reactionCount: reactions.length,
        color: ref.watch(colorOfUserProvider(message.authorId)),
        quote: quote,
        attachment: event == null
            ? null
            : SizedBox(
                width: 240,
                child: EventCard(
                  event: event,
                  accent: planAccent(ref, event),
                  onTap: () => context.push('/event/${event.id}'),
                ),
              ),
        attachedItem: message.attachedItemId != null ? ref.watch(itemByIdProvider(message.attachedItemId!)).valueOrNull : null,
        onTapAttachment: message.attachedItemId != null ? () => context.push('/item/${message.attachedItemId}') : null,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final TwinsChat? chat;
  final VoidCallback? onRename;
  const _ChatHeader({required this.chat, required this.onRename});

  @override
  Widget build(BuildContext context) {
    final title = chat?.name ?? (chat == null ? '' : 'Naming…');
    return Padding(
      padding: const EdgeInsets.fromLTRB(TwinsSpacing.xs, TwinsSpacing.sm, TwinsSpacing.md, TwinsSpacing.sm),
      child: Row(
        children: [
          IconButton(icon: const Icon(PhosphorIconsBold.caretLeft), onPressed: () => Navigator.of(context).maybePop()),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TwinsTypography.heading(context.twins.textPrimary, size: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRename != null) ...[
                    const SizedBox(width: 6),
                    Icon(PhosphorIconsBold.pencilSimple, size: 14, color: context.twins.textSecondary),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
