import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/item.dart';
import '../../data/models/message.dart';
import '../../data/models/profile.dart';
import '../../data/models/reaction.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/avatars.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/item_card.dart';
import '../../widgets/reaction_bar.dart';
import '../../widgets/twins_bottom_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            return Column(
              children: [
                membersAsync.when(
                  data: (members) => _ChatHeader(members: members, meId: me?.id, spaceName: space.name),
                  loading: () => const SizedBox(height: 56),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Consumer(builder: (context, ref, _) {
                    final messagesAsync = ref.watch(messagesProvider(space.id));
                    return messagesAsync.when(
                      data: (messages) {
                        if (messages.isEmpty) {
                          return const EmptyState(emoji: '💬', title: 'Say hi to start the conversation');
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                          }
                        });
                        return membersAsync.when(
                          data: (members) => ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(TwinsSpacing.md),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMine = message.authorId == me?.id;
                              final author = members.firstWhere(
                                (m) => m.id == message.authorId,
                                orElse: () => Profile(id: message.authorId, displayName: 'Twin', username: 'twin', createdAt: message.createdAt),
                              );
                              return _MessageBubble(
                                message: message,
                                isMine: isMine,
                                senderLabel: isMine ? 'You' : author.displayName,
                              );
                            },
                          ),
                          loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
                          error: (e, _) => const SizedBox.shrink(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
                      error: (e, _) => const SizedBox.shrink(),
                    );
                  }),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    TwinsSpacing.md,
                    TwinsSpacing.xs,
                    TwinsSpacing.md,
                    TwinsSpacing.xs + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(PhosphorIconsBold.plus, color: TwinsColors.mikuGreen), onPressed: () => _showAttachMenu(space.id)),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Say something...'),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(space.id),
                        ),
                      ),
                      const SizedBox(width: TwinsSpacing.sm),
                      CircleAvatar(
                        backgroundColor: TwinsColors.mikuGreen,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                          onPressed: () => _send(space.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _send(String spaceId) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(repositoryProvider).sendMessage(spaceId: spaceId, body: text);
  }

  Future<void> _showAttachMenu(String spaceId) async {
    final choice = await showTwinsBottomSheet<_AttachChoice>(
      context: context,
      title: 'Share to chat',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsBold.plusCircle, color: TwinsColors.mikuGreen),
            title: const Text('New item'),
            subtitle: const Text('Save a link, photo, file, or note'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.newItem),
          ),
          ListTile(
            leading: const Icon(PhosphorIconsBold.stack, color: TwinsColors.mikuGreen),
            title: const Text('Existing item'),
            subtitle: const Text('Point to something already saved'),
            onTap: () => Navigator.of(context).pop(_AttachChoice.existingItem),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _AttachChoice.newItem) {
      context.push('/add');
    } else {
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
            loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
            error: (e, _) => const EmptyState(emoji: '⚠️', title: "Couldn't load items"),
          );
        }),
      ),
    );
  }

  Future<void> _sendAttachment(String spaceId, TwinsItem item) async {
    await ref.read(repositoryProvider).sendMessage(
          spaceId: spaceId,
          body: item.title,
          attachedItemId: item.id,
        );
  }
}

enum _AttachChoice { newItem, existingItem }

class _MessageBubble extends ConsumerWidget {
  final TwinsMessage message;
  final bool isMine;
  final String senderLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(
      reactionsProvider(ReactionQuery(message.spaceId, ReactionTargetType.message, message.id)),
    );
    final reactions = reactionsAsync.valueOrNull ?? const [];

    Future<void> react(String emoji) => ref.read(repositoryProvider).toggleReaction(
          spaceId: message.spaceId,
          targetType: ReactionTargetType.message,
          targetId: message.id,
          emoji: emoji,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ChatBubble(
        body: message.body,
        createdAt: message.createdAt,
        isMine: isMine,
        senderLabel: senderLabel,
        reactionCount: reactions.length,
        attachedItem: message.attachedItemId != null ? ref.watch(itemByIdProvider(message.attachedItemId!)).valueOrNull : null,
        onTapAttachment: message.attachedItemId != null ? () => context.push('/item/${message.attachedItemId}') : null,
        onLongPress: () async {
          final emoji = await showReactionPicker(context);
          if (emoji != null) await react(emoji);
        },
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final List<Profile> members;
  final String? meId;
  final String spaceName;
  const _ChatHeader({required this.members, required this.meId, required this.spaceName});

  @override
  Widget build(BuildContext context) {
    // Prefer the twin (the member who isn't me) for the avatar + subtitle.
    final twin = members.where((m) => m.id != meId).cast<Profile?>().firstWhere((_) => true, orElse: () => null) ??
        (members.isNotEmpty ? members.first : null);
    final subtitle = twin != null && twin.id != meId
        ? 'with ${twin.displayName}'
        : 'Waiting for your twin to join…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(TwinsSpacing.md, TwinsSpacing.sm, TwinsSpacing.md, TwinsSpacing.sm),
      child: Row(
        children: [
          if (twin != null) UserAvatar(profile: twin, size: 40),
          const SizedBox(width: TwinsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spaceName, style: TwinsTypography.heading(context.twins.textPrimary, size: 17), overflow: TextOverflow.ellipsis),
                Text(subtitle, style: TwinsTypography.body(TwinsColors.mikuGreen, size: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
