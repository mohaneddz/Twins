import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/event.dart';
import '../../data/models/profile.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatars.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/item_card.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';
import 'event_editor_sheet.dart';

/// One plan: when, the reminder, notes, what it's about, and what can be done
/// with it (edit, send to a chat, call off).
class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.twins;
    final space = ref.watch(currentSpaceProvider).valueOrNull;
    if (space == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)));
    final eventsAsync = ref.watch(eventsProvider(space.id));
    final event = eventsAsync.valueOrNull?.where((e) => e.id == eventId).firstOrNull;
    final me = ref.watch(authStateProvider).valueOrNull;

    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: eventsAsync.isLoading
            ? const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen))
            : const EmptyState(emoji: '🗓️', title: 'This plan is gone'),
      );
    }

    final members = ref.watch(spaceMembersProvider(space.id)).valueOrNull ?? const <Profile>[];
    final author = members.where((m) => m.id == event.createdBy).firstOrNull;
    final accent = planAccent(event, me?.id);
    final item = event.itemId == null ? null : ref.watch(itemByIdProvider(event.itemId!)).valueOrNull;

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: TwinsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: TwinsSpacing.sm),
              Expanded(child: Text(text, style: TwinsTypography.body(palette.textPrimary))),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!event.isCancelled)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(PhosphorIconsBold.pencilSimple),
              onPressed: () => showEventEditor(context, spaceId: space.id, existing: event),
            ),
          IconButton(
            tooltip: 'Send to a chat',
            icon: const Icon(PhosphorIconsBold.paperPlaneTilt),
            onPressed: () => sharePlanToChat(context, ref, event),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, 0, TwinsSpacing.lg, TwinsSpacing.xxl),
        children: [
          if (event.isCancelled)
            Container(
              margin: const EdgeInsets.only(bottom: TwinsSpacing.md),
              padding: const EdgeInsets.all(TwinsSpacing.sm),
              decoration: BoxDecoration(color: TwinsColors.danger.withValues(alpha: 0.12), borderRadius: TwinsRadius.smRadius),
              child: Text('This plan was called off', style: TwinsTypography.label(TwinsColors.danger)),
            ),
          Text(
            event.title,
            style: TwinsTypography.heading(palette.textPrimary, size: 26).copyWith(
              decoration: event.isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: TwinsSpacing.lg),
          line(PhosphorIconsBold.calendarBlank, formatPlanWhen(startsAt: event.startsAt, endsAt: event.endsAt, allDay: event.allDay)),
          line(PhosphorIconsBold.bellRinging, formatReminder(event.remindMinutes)),
          if ((event.notes ?? '').isNotEmpty) line(PhosphorIconsBold.note, event.notes!),
          if (author != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TwinsSpacing.sm),
              child: Row(
                children: [
                  UserAvatar(profile: author, size: 22),
                  const SizedBox(width: TwinsSpacing.sm),
                  Text(
                    author.id == me?.id ? 'You planned this' : '${author.displayName} planned this',
                    style: TwinsTypography.body(palette.textSecondary, size: 13.5),
                  ),
                ],
              ),
            ),
          if (item != null) ...[
            const SizedBox(height: TwinsSpacing.md),
            Text('About', style: TwinsTypography.label(palette.textSecondary)),
            const SizedBox(height: TwinsSpacing.xs),
            SizedBox(
              width: 180,
              child: ItemCard(item: item, onTap: () => context.push('/item/${item.id}')),
            ),
          ],
          if (event.chatId != null) ...[
            const SizedBox(height: TwinsSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(PhosphorIconsBold.chatCircle, size: 18),
              label: const Text('Open the chat it came from'),
              onPressed: () => context.push('/chat/${event.chatId}'),
            ),
          ],
          const SizedBox(height: TwinsSpacing.xl),
          if (event.isCancelled)
            FilledButton(
              onPressed: () => ref.read(repositoryProvider).updateEvent(event.copyWith(restore: true)),
              child: const Text('Bring it back'),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: TwinsColors.danger),
              icon: const Icon(PhosphorIconsBold.xCircle, size: 18),
              label: const Text('Call it off'),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Call off "${event.title}"?',
                  message: 'Your twin gets told, and the reminder is dropped on both phones.',
                  confirmLabel: 'Call it off',
                );
                if (ok) await ref.read(repositoryProvider).cancelEvent(event.id);
              },
            ),
        ],
      ),
    );
  }
}

/// Picks a chat and posts the plan there as a card.
Future<void> sharePlanToChat(BuildContext context, WidgetRef ref, TwinsEvent event) async {
  final chats = ref.read(chatsProvider(event.spaceId)).valueOrNull ?? const [];
  final repo = ref.read(repositoryProvider);
  final chatId = await showTwinsBottomSheet<String>(
    context: context,
    title: 'Send to a chat',
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsBold.plusCircle, color: TwinsColors.mikuGreen),
            title: const Text('New chat'),
            onTap: () async {
              final chat = await repo.createChat(spaceId: event.spaceId, name: event.title);
              if (context.mounted) Navigator.of(context).pop(chat.id);
            },
          ),
          for (final chat in chats)
            ListTile(
              leading: const Icon(PhosphorIconsRegular.chatCircle),
              title: Text(chat.name ?? 'New chat', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(chat.id),
            ),
        ],
      ),
    ),
  );
  if (chatId == null) return;
  await repo.sendMessage(spaceId: event.spaceId, chatId: chatId, body: '', attachedEventId: event.id);
  if (context.mounted) showTwinsToast(context, 'Sent to the chat');
}
