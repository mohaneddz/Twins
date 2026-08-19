import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/chat.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';
import '../../widgets/twins_input.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    return Scaffold(
      body: SafeArea(
        child: spaceAsync.when(
          data: (space) {
            if (space == null) return const SizedBox.shrink();
            final chatsAsync = ref.watch(chatsProvider(space.id));
            return Column(
              children: [
                ScreenHeader(
                  title: 'Chats',
                  showBack: false,
                  actions: [
                    IconButton(
                      icon: const Icon(PhosphorIconsBold.plus, color: TwinsColors.mikuGreen),
                      onPressed: () => _createChat(context, ref, space.id),
                    ),
                  ],
                ),
                Expanded(
                  child: chatsAsync.when(
                    data: (chats) {
                      if (chats.isEmpty) {
                        return EmptyState(
                          emoji: '💬',
                          title: 'No chats yet',
                          subtitle: 'Start one and say hi 👋',
                          action: FilledButton(
                            onPressed: () => _createChat(context, ref, space.id),
                            child: const Text('New chat'),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.sm),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return _ChatTile(
                            chat: chat,
                            onTap: () => context.push('/chat/${chat.id}'),
                            onLongPress: () => _showChatOptions(context, ref, chat),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
                    error: (e, _) => const SizedBox.shrink(),
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

  Future<void> _createChat(BuildContext context, WidgetRef ref, String spaceId) async {
    final chat = await ref.read(repositoryProvider).createChat(spaceId: spaceId);
    if (context.mounted) context.push('/chat/${chat.id}');
  }

  Future<void> _showChatOptions(BuildContext context, WidgetRef ref, TwinsChat chat) async {
    await showTwinsBottomSheet(
      context: context,
      title: chat.name ?? 'Untitled chat',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(context).pop();
              showRenameChatSheet(context, ref, chat);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: TwinsColors.danger),
            title: const Text('Delete chat', style: TextStyle(color: TwinsColors.danger)),
            onTap: () async {
              Navigator.of(context).pop();
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete "${chat.name ?? 'Untitled chat'}"?',
                message: 'This deletes the chat and every message in it. This cannot be undone.',
              );
              if (confirmed) {
                await ref.read(repositoryProvider).deleteChat(chat.id);
                if (context.mounted) showTwinsToast(context, 'Chat deleted');
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showRenameChatSheet(BuildContext context, WidgetRef ref, TwinsChat chat) async {
  final controller = TextEditingController(text: chat.name);
  await showTwinsBottomSheet(
    context: context,
    title: 'Rename chat',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TwinsInput(hint: 'Chat name', controller: controller),
        const SizedBox(height: TwinsSpacing.lg),
        FilledButton(
          onPressed: () async {
            if (controller.text.trim().isEmpty) return;
            await ref.read(repositoryProvider).renameChat(chat.id, controller.text.trim());
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _ChatTile extends StatelessWidget {
  final TwinsChat chat;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatTile({required this.chat, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: TwinsColors.mikuMist,
        child: const Icon(PhosphorIconsBold.chatCircleDots, color: TwinsColors.mikuGreen),
      ),
      title: Text(
        chat.name ?? 'Untitled chat',
        style: TwinsTypography.heading(palette.textPrimary, size: 15),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chat.name == null
          ? Text('Naming this chat…', style: TwinsTypography.body(palette.textSecondary, size: 13))
          : null,
      trailing: Text(formatRelativeTime(chat.updatedAt), style: TwinsTypography.label(palette.textSecondary, size: 12)),
      shape: RoundedRectangleBorder(borderRadius: TwinsRadius.smRadius),
    );
  }
}
