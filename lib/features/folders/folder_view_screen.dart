import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/item_type.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_twins.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/item_card.dart';
import '../../widgets/toast.dart';
import 'folder_dialogs.dart';

class FolderViewScreen extends ConsumerStatefulWidget {
  final String folderId;
  const FolderViewScreen({super.key, required this.folderId});

  @override
  ConsumerState<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends ConsumerState<FolderViewScreen> {
  ItemType? _filter;
  bool _selecting = false;
  final _selected = <String>{};

  static const _filters = <String, ItemType?>{
    'All': null,
    'Reels': ItemType.reel,
    'TikToks': ItemType.tiktok,
    'Shorts': ItemType.short,
    'Videos': ItemType.video,
    'Images': ItemType.image,
    'Notes': ItemType.note,
    'Docs': ItemType.document,
    'Links': ItemType.link,
  };

  @override
  Widget build(BuildContext context) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    final folderAsync = ref.watch(folderByIdProvider(widget.folderId));

    // The header takes the folder's own colour (it was pinned to brand green
    // regardless of the folder), so the chrome has to derive its contrast.
    final headerColor = folderAsync.valueOrNull?.color ?? TwinsColors.mikuGreen;
    final onHeader = onColor(headerColor);
    final onHeaderMuted = onHeader.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: headerColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TwinsSpacing.md, TwinsSpacing.xs, TwinsSpacing.md, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIconsBold.caretLeft, color: onHeader),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (_selecting)
                    IconButton(
                      icon: Icon(PhosphorIconsBold.x, color: onHeader),
                      onPressed: () => setState(() {
                        _selecting = false;
                        _selected.clear();
                      }),
                    )
                  else ...[
                    IconButton(
                      icon: Icon(PhosphorIconsBold.export, color: onHeader),
                      onPressed: () => Share.share('Check out our folder on ¡Twins!'),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIconsBold.dotsThreeVertical, color: onHeader),
                      onPressed: () {
                        final folder = folderAsync.valueOrNull;
                        if (folder != null) showFolderOptionsSheet(context, ref, folder);
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, 0, TwinsSpacing.lg, TwinsSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: onHeader.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: Text(folderAsync.valueOrNull?.icon ?? '📁', style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: TwinsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folderAsync.valueOrNull?.name ?? '',
                          style: TwinsTypography.heading(onHeader, size: 22),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${folderAsync.valueOrNull?.itemCount ?? 0} items',
                          style: TwinsTypography.body(onHeaderMuted, size: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: spaceAsync.when(
                  data: (space) {
                    if (space == null) return const SizedBox.shrink();
                    return _FolderContent(
                      spaceId: space.id,
                      folderId: widget.folderId,
                      filter: _filter,
                      selecting: _selecting,
                      selected: _selected,
                      filters: _filters,
                      onFilterChange: (v) => setState(() => _filter = v),
                      onToggleSelect: (id) => setState(() {
                        if (_selected.contains(id)) {
                          _selected.remove(id);
                        } else {
                          _selected.add(id);
                        }
                      }),
                      onStartSelecting: (id) => setState(() {
                        _selecting = true;
                        _selected.add(id);
                      }),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              backgroundColor: TwinsColors.mikuGreen,
              onPressed: () => context.push('/add', extra: {'folderId': widget.folderId}),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: (_selecting && _selected.isNotEmpty)
          ? _SelectionBar(
              count: _selected.length,
              onMove: () => _moveSelected(spaceAsync.valueOrNull?.id),
              onDelete: _deleteSelected,
            )
          : null,
    );
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${_selected.length} ${_selected.length == 1 ? 'item' : 'items'}?',
      message: 'This removes them for both of you. This cannot be undone.',
    );
    if (!confirmed) return;
    final repo = ref.read(repositoryProvider);
    for (final id in _selected) {
      await repo.deleteItem(id);
    }
    if (mounted) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    }
  }

  Future<void> _moveSelected(String? spaceId) async {
    if (spaceId == null) return;
    final targetId = await showMoveToFolderSheet(context, ref, spaceId, excludeFolderId: widget.folderId);
    if (targetId == null) return;
    final repo = ref.read(repositoryProvider);
    for (final id in _selected) {
      final item = await repo.getItem(id);
      if (item != null) await repo.updateItem(item.copyWith(folderId: targetId));
    }
    if (mounted) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
      showTwinsToast(context, 'Moved');
    }
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  const _SelectionBar({required this.count, required this.onMove, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.md, vertical: TwinsSpacing.sm),
          child: Row(
            children: [
              Text('$count selected', style: TwinsTypography.label(Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              TextButton.icon(
                onPressed: onMove,
                icon: const Icon(PhosphorIconsRegular.folderSimple, size: 20),
                label: const Text('Move'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20, color: TwinsColors.danger),
                label: const Text('Delete', style: TextStyle(color: TwinsColors.danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderContent extends ConsumerWidget {
  final String spaceId;
  final String folderId;
  final ItemType? filter;
  final bool selecting;
  final Set<String> selected;
  final Map<String, ItemType?> filters;
  final ValueChanged<ItemType?> onFilterChange;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onStartSelecting;

  const _FolderContent({
    required this.spaceId,
    required this.folderId,
    required this.filter,
    required this.selecting,
    required this.selected,
    required this.filters,
    required this.onFilterChange,
    required this.onToggleSelect,
    required this.onStartSelecting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subfoldersAsync = ref.watch(foldersProvider(FolderQuery(spaceId, folderId)));
    final itemsAsync = ref.watch(itemsProvider(ItemQuery(spaceId, folderId, filter)));

    return Column(
      children: [
        const SizedBox(height: TwinsSpacing.md),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.md),
            children: filters.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TwinsFilterChip(
                        label: e.key,
                        selected: filter == e.value,
                        onTap: () => onFilterChange(e.value),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: TwinsSpacing.sm),
        Expanded(
          child: subfoldersAsync.when(
            data: (subfolders) => itemsAsync.when(
              data: (items) {
                if (items.isEmpty && subfolders.isEmpty) {
                  return const EmptyState(
                    emoji: '📦',
                    title: 'Nothing here yet.',
                    subtitle: 'Send something from TikTok, YouTube, or anywhere.',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(TwinsSpacing.md, 0, TwinsSpacing.md, 90),
                  itemCount: subfolders.length + items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: TwinsSpacing.sm,
                    crossAxisSpacing: TwinsSpacing.sm,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    if (index < subfolders.length) {
                      final f = subfolders[index];
                      return FolderCard(folder: f, onTap: () => context.push('/folder/${f.id}'));
                    }
                    final item = items[index - subfolders.length];
                    final isSelected = selected.contains(item.id);
                    return ItemCard(
                      item: item,
                      selected: isSelected,
                      onTap: () {
                        if (selecting) {
                          onToggleSelect(item.id);
                        } else {
                          context.push('/item/${item.id}');
                        }
                      },
                      onLongPress: () => onStartSelecting(item.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
              error: (e, _) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
