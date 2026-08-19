import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/profile.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/screen_header.dart';

/// Lightweight shared activity surface (spec section 36) - "Mohaned added a
/// reel to Funny Reels", "Rania sent a message" - not a social feed, just a
/// quick glance at what's happened recently in the space.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    return Scaffold(
      appBar: const ScreenHeader(title: 'Activity'),
      body: spaceAsync.when(
        data: (space) {
          if (space == null) return const SizedBox.shrink();
          final itemsAsync = ref.watch(recentItemsProvider(space.id));
          final messagesAsync = ref.watch(recentMessagesProvider(space.id));
          final membersAsync = ref.watch(spaceMembersProvider(space.id));

          return membersAsync.when(
            data: (members) {
              Profile authorOf(String id) => members.firstWhere(
                    (m) => m.id == id,
                    orElse: () => Profile(id: id, displayName: 'Twin', username: 'twin', createdAt: DateTime.now()),
                  );

              final events = <_ActivityEvent>[
                ...itemsAsync.valueOrNull?.map((i) => _ActivityEvent(
                          time: i.createdAt,
                          icon: PhosphorIconsFill.plusCircle,
                          text: '${authorOf(i.createdBy).displayName} added "${i.title}"',
                          onTap: () => context.push('/item/${i.id}'),
                        )) ??
                    const [],
                ...messagesAsync.valueOrNull?.take(15).map((m) => _ActivityEvent(
                          time: m.createdAt,
                          icon: PhosphorIconsFill.chatCircle,
                          text: '${authorOf(m.authorId).displayName} sent a message',
                        )) ??
                    const [],
              ]..sort((a, b) => b.time.compareTo(a.time));

              if (events.isEmpty) {
                return const EmptyState(emoji: '✨', title: 'Nothing yet', subtitle: "Activity will show up here as you both use the space.");
              }

              return ListView.separated(
                padding: const EdgeInsets.all(TwinsSpacing.lg),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: TwinsSpacing.xs),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return InkWell(
                    borderRadius: TwinsRadius.mdRadius,
                    onTap: event.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(TwinsSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: TwinsRadius.mdRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(event.icon, color: TwinsColors.mikuGreen, size: 20),
                          const SizedBox(width: TwinsSpacing.sm),
                          Expanded(child: Text(event.text, style: TwinsTypography.body(Theme.of(context).colorScheme.onSurface, size: 14))),
                          Text(formatRelativeTime(event.time), style: TwinsTypography.label(context.twins.textSecondary, size: 11)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
            error: (e, _) => const SizedBox.shrink(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _ActivityEvent {
  final DateTime time;
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ActivityEvent({required this.time, required this.icon, required this.text, this.onTap});
}
