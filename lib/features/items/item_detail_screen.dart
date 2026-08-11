import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/item.dart';
import '../../data/models/item_type.dart';
import '../../data/models/profile.dart';
import '../../data/models/reaction.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/comment_bubble.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/media_thumbnail.dart';
import '../../widgets/platform_badge.dart';
import '../../widgets/reaction_bar.dart';
import '../../widgets/toast.dart';
import 'video_player_view.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final _commentController = TextEditingController();
  VideoPlayerController? _videoController;
  int? _pendingTimestampMs;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemByIdProvider(widget.itemId));

    return Scaffold(
      // Deliberately dark in both themes. This is a full-bleed media viewer
      // (see design/05_Item_Detail.png) where the artwork is the content and
      // light chrome would wash it out - the same call TikTok/Instagram make.
      // Everything here is drawn on that dark ground, so it does not read
      // from the palette.
      backgroundColor: TwinsColors.navy,
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('This item is gone.', style: TextStyle(color: Colors.white)));
          }
          final isMedia = item.type == ItemType.video || item.type == ItemType.audio;
          return Column(
            children: [
              Expanded(
                child: _ItemDetailBody(
                  item: item,
                  onVideoReady: (c) => _videoController = c,
                  onSeek: (ms) => _videoController?.seekTo(Duration(milliseconds: ms)),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    TwinsSpacing.md,
                    TwinsSpacing.xs,
                    TwinsSpacing.md,
                    TwinsSpacing.xs + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Row(
                    children: [
                      if (isMedia)
                        IconButton(
                          icon: const Icon(PhosphorIconsBold.clock, color: TwinsColors.mikuGreen),
                          tooltip: 'Comment at current timestamp',
                          onPressed: () {
                            final ms = _videoController?.value.position.inMilliseconds;
                            if (ms != null) setState(() => _pendingTimestampMs = ms);
                          },
                        ),
                      Expanded(
                        child: _DarkComposer(
                          controller: _commentController,
                          timestampLabel: _pendingTimestampMs != null ? formatTimestamp(_pendingTimestampMs!) : null,
                          onClearTimestamp: () => setState(() => _pendingTimestampMs = null),
                          onSend: () async {
                            final text = _commentController.text.trim();
                            if (text.isEmpty) return;
                            await ref.read(repositoryProvider).addComment(
                                  itemId: item.id,
                                  body: text,
                                  mediaTimestampMs: _pendingTimestampMs,
                                );
                            _commentController.clear();
                            setState(() => _pendingTimestampMs = null);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
        error: (e, _) => const Center(child: Text('Something went wrong.', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerWidget {
  final TwinsItem item;
  final ValueChanged<VideoPlayerController> onVideoReady;
  final ValueChanged<int> onSeek;

  const _ItemDetailBody({
    required this.item,
    required this.onVideoReady,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(spaceMembersProvider(item.spaceId));
    final commentsAsync = ref.watch(commentsProvider(item.id));
    final reactionsAsync = ref.watch(reactionsProvider(ReactionQuery(item.spaceId, ReactionTargetType.item, item.id)));
    final me = ref.watch(authStateProvider).valueOrNull;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.sm),
            child: Row(
              children: [
                IconButton(icon: const Icon(PhosphorIconsBold.caretLeft, color: Colors.white), onPressed: () => context.pop()),
                const Spacer(),
                IconButton(
                  icon: Icon(item.isPinned ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple, color: Colors.white),
                  onPressed: () async {
                    await ref.read(repositoryProvider).updateItem(item.copyWith(isPinned: !item.isPinned));
                    ref.invalidate(itemByIdProvider(item.id));
                  },
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsBold.dotsThreeVertical, color: Colors.white),
                  onPressed: () => _showItemMenu(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRenderer(context),
                  Padding(
                    padding: const EdgeInsets.all(TwinsSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: TwinsTypography.heading(Colors.white, size: 20)),
                        if (item.description != null && item.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.description!, style: TwinsTypography.body(Colors.white70)),
                        ],
                        _ItemTags(itemId: item.id),
                        const SizedBox(height: TwinsSpacing.md),
                        membersAsync.when(
                          data: (members) {
                            final author = members.firstWhere(
                              (m) => m.id == item.createdBy,
                              orElse: () => Profile(id: item.createdBy, displayName: 'Twin', username: 'twin', createdAt: item.createdAt),
                            );
                            return Container(
                              padding: const EdgeInsets.all(TwinsSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(PhosphorIconsFill.folder, color: TwinsColors.mikuGreen, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Added by ${author.displayName} • ${formatRelativeTime(item.createdAt)} ago',
                                      style: TwinsTypography.body(Colors.white70, size: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: TwinsSpacing.md),
                        reactionsAsync.when(
                          data: (reactions) {
                            final counts = <String, int>{};
                            for (final r in reactions) {
                              counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
                            }
                            final mine = reactions.any((r) => r.userId == me?.id && r.emoji == '❤️');
                            return ReactionBar(
                              counts: counts,
                              myReactionActive: mine,
                              onTapHeart: () => ref.read(repositoryProvider).toggleReaction(
                                    spaceId: item.spaceId,
                                    targetType: ReactionTargetType.item,
                                    targetId: item.id,
                                    emoji: '❤️',
                                  ),
                              onLongPressForPicker: () async {
                                final emoji = await showReactionPicker(context);
                                if (emoji != null) {
                                  await ref.read(repositoryProvider).toggleReaction(
                                        spaceId: item.spaceId,
                                        targetType: ReactionTargetType.item,
                                        targetId: item.id,
                                        emoji: emoji,
                                      );
                                }
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: TwinsSpacing.lg),
                        Text('Comments', style: TwinsTypography.heading(Colors.white, size: 16)),
                        const SizedBox(height: TwinsSpacing.sm),
                        commentsAsync.when(
                          data: (comments) {
                            if (comments.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.md),
                                child: Text('Be the first to say something 👀', style: TwinsTypography.body(Colors.white54)),
                              );
                            }
                            return membersAsync.when(
                              data: (members) => Column(
                                children: comments.map((c) {
                                  final author = members.firstWhere(
                                    (m) => m.id == c.authorId,
                                    orElse: () => Profile(id: c.authorId, displayName: 'Twin', username: 'twin', createdAt: c.createdAt),
                                  );
                                  return _DarkCommentWrapper(
                                    child: CommentBubble(comment: c, author: author, onTapTimestamp: onSeek),
                                  );
                                }).toList(),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (e, _) => const SizedBox.shrink(),
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(TwinsSpacing.md),
                            child: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
                          ),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Comment composer pinned above the keyboard.
    );
  }

  Widget _buildRenderer(BuildContext context) {
    switch (item.type) {
      case ItemType.video:
      case ItemType.audio:
        return item.storagePath != null || item.sourceUrl != null
            ? VideoPlayerView(url: item.sourceUrl ?? item.storagePath!, onControllerReady: onVideoReady)
            : _fallbackThumb(context);
      case ItemType.image:
      case ItemType.gif:
        return _ImageViewer(url: item.thumbnailUrl);
      case ItemType.note:
        return _NoteRenderer(item: item);
      case ItemType.document:
        return _DocumentRenderer(item: item);
      case ItemType.youtube:
        return _PreviewWithOpenButton(item: item, openLabel: 'Open in YouTube');
      case ItemType.tiktok:
        return _PreviewWithOpenButton(item: item, openLabel: 'Open in TikTok');
      case ItemType.reel:
      case ItemType.short:
        return _PreviewWithOpenButton(item: item, openLabel: 'Open original');
      case ItemType.link:
      case ItemType.other:
        return _LinkRenderer(item: item);
    }
  }

  Widget _fallbackThumb(BuildContext context) => AspectRatio(
        aspectRatio: 4 / 3,
        child: MediaThumbnail(
          url: item.thumbnailUrl,
          fallbackIcon: PlatformBadge.visualFor(item.type).$1,
          fallbackColor: PlatformBadge.visualFor(item.type).$2,
        ),
      );

  void _showItemMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.folderSimple),
              title: const Text('Move to folder'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showMoveToFolder(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.export),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final text = item.sourceUrl ?? item.content ?? item.title;
                Share.share(item.sourceUrl != null ? text : '${item.title}\n\n$text');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: TwinsColors.danger),
              title: const Text('Delete item', style: TextStyle(color: TwinsColors.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete this item?',
                  message: 'This removes it for both of you. This cannot be undone.',
                );
                if (confirmed) {
                  await ref.read(repositoryProvider).deleteItem(item.id);
                  if (context.mounted) {
                    context.pop();
                    showTwinsToast(context, 'Item deleted');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolder(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final foldersAsync = ref.watch(foldersProvider(FolderQuery(item.spaceId, null)));
            return foldersAsync.when(
              data: (folders) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(TwinsSpacing.md),
                    child: Text('Move to folder', style: TwinsTypography.heading(Theme.of(context).colorScheme.onSurface, size: 16)),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: folders.map((f) {
                        final isCurrent = f.id == item.folderId;
                        return ListTile(
                          leading: Text(f.icon, style: const TextStyle(fontSize: 22)),
                          title: Text(f.name),
                          trailing: isCurrent ? const Icon(PhosphorIconsFill.checkCircle, color: TwinsColors.mikuGreen) : null,
                          onTap: isCurrent
                              ? null
                              : () async {
                                  Navigator.of(sheetContext).pop();
                                  await ref.read(repositoryProvider).updateItem(item.copyWith(folderId: f.id));
                                  ref.invalidate(itemByIdProvider(item.id));
                                  if (context.mounted) showTwinsToast(context, 'Moved to ${f.name}');
                                },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: TwinsSpacing.sm),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(TwinsSpacing.xl),
                child: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
              ),
              error: (e, _) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}

/// Tag chips on the item detail. Tapping one opens search pre-filled with that
/// tag. Renders nothing until the item has tags.
class _ItemTags extends ConsumerWidget {
  final String itemId;
  const _ItemTags({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(itemTagsProvider(itemId)).valueOrNull ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TwinsSpacing.sm),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tags)
            ActionChip(
              label: Text('#${t.name}'),
              labelStyle: TwinsTypography.label(Colors.white, size: 12),
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () => context.push('/search?q=${Uri.encodeComponent(t.name)}'),
            ),
        ],
      ),
    );
  }
}

class _DarkComposer extends StatelessWidget {
  final TextEditingController controller;
  final String? timestampLabel;
  final VoidCallback onClearTimestamp;
  final VoidCallback onSend;

  const _DarkComposer({
    required this.controller,
    required this.timestampLabel,
    required this.onClearTimestamp,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
              fillColor: Colors.white.withValues(alpha: 0.08),
              hintStyle: const TextStyle(color: Colors.white54),
            ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: CommentComposer(
          controller: controller,
          onSend: onSend,
          timestampLabel: timestampLabel,
          onClearTimestamp: onClearTimestamp,
        ),
      ),
    );
  }
}

class _DarkCommentWrapper extends StatelessWidget {
  final Widget child;
  const _DarkCommentWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String? url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: AspectRatio(aspectRatio: 1, child: MediaThumbnail(url: url)),
    );
  }
}

class _NoteRenderer extends StatelessWidget {
  final TwinsItem item;
  const _NoteRenderer({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.md, TwinsSpacing.lg, 0),
      padding: const EdgeInsets.all(TwinsSpacing.lg),
      decoration: BoxDecoration(
        color: TwinsColors.folderPeach.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: MarkdownBody(
        data: item.content ?? '',
        styleSheet: MarkdownStyleSheet(
          p: TwinsTypography.body(Colors.white, size: 15),
          listBullet: TwinsTypography.body(Colors.white, size: 15),
        ),
      ),
    );
  }
}

class _DocumentRenderer extends StatelessWidget {
  final TwinsItem item;
  const _DocumentRenderer({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.md, TwinsSpacing.lg, 0),
      padding: const EdgeInsets.all(TwinsSpacing.xl),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(PhosphorIconsFill.fileText, color: TwinsColors.vibrantBlue, size: 48),
          const SizedBox(height: TwinsSpacing.sm),
          Text(item.title, style: TwinsTypography.body(Colors.white)),
          const SizedBox(height: TwinsSpacing.md),
          if (item.sourceUrl != null || item.storagePath != null)
            OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(item.sourceUrl ?? item.storagePath!), mode: LaunchMode.externalApplication),
              child: const Text('Open document'),
            ),
        ],
      ),
    );
  }
}

class _PreviewWithOpenButton extends StatelessWidget {
  final TwinsItem item;
  final String openLabel;
  const _PreviewWithOpenButton({required this.item, required this.openLabel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: MediaThumbnail(
            url: item.thumbnailUrl,
            fallbackIcon: PlatformBadge.visualFor(item.type).$1,
            fallbackColor: PlatformBadge.visualFor(item.type).$2,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(TwinsSpacing.md),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
            ),
            child: Row(
              children: [
                Expanded(child: Text(item.title, style: TwinsTypography.body(Colors.white))),
                const SizedBox(width: TwinsSpacing.sm),
                if (item.sourceUrl != null)
                  FilledButton.tonal(
                    onPressed: () => launchUrl(Uri.parse(item.sourceUrl!), mode: LaunchMode.externalApplication),
                    child: Text(openLabel),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRenderer extends StatelessWidget {
  final TwinsItem item;
  const _LinkRenderer({required this.item});

  @override
  Widget build(BuildContext context) {
    final domain = item.sourceUrl != null ? Uri.tryParse(item.sourceUrl!)?.host ?? '' : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.md, TwinsSpacing.lg, 0),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.thumbnailUrl != null) AspectRatio(aspectRatio: 16 / 9, child: MediaThumbnail(url: item.thumbnailUrl)),
          Padding(
            padding: const EdgeInsets.all(TwinsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(domain, style: TwinsTypography.label(TwinsColors.mikuGreen, size: 12)),
                const SizedBox(height: 4),
                Text(item.title, style: TwinsTypography.heading(Colors.white, size: 16)),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(item.description!, style: TwinsTypography.body(Colors.white70, size: 13)),
                ],
                const SizedBox(height: TwinsSpacing.sm),
                if (item.sourceUrl != null)
                  FilledButton(
                    onPressed: () => launchUrl(Uri.parse(item.sourceUrl!), mode: LaunchMode.externalApplication),
                    child: const Text('Open link'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
