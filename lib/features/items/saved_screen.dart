import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/item.dart';
import '../../data/models/item_type.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_twins.dart';
import '../../widgets/item_card.dart';
import '../../widgets/item_selection_bar.dart';

enum _Kind {
  all('All', null),
  videos('Videos', {ItemType.reel, ItemType.tiktok, ItemType.youtube, ItemType.short, ItemType.video}),
  photos('Photos', {ItemType.image, ItemType.gif}),
  notes('Notes', {ItemType.note}),
  links('Links', {ItemType.link}),
  files('Files', {ItemType.document, ItemType.audio, ItemType.other});

  final String label;
  final Set<ItemType>? types;
  const _Kind(this.label, this.types);
}

/// Everything the two of us saved, in one grid: filter by kind or to what
/// isn't in a folder yet, and long-press to sort several at once.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _Kind _kind = _Kind.all;
  bool _unfiledOnly = false;
  final _selected = <String>{};

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final space = ref.watch(currentSpaceProvider).valueOrNull;
    final itemsAsync = space == null ? const AsyncValue<List<TwinsItem>>.loading() : ref.watch(allItemsProvider(space.id));
    final all = itemsAsync.valueOrNull ?? const <TwinsItem>[];
    final shown = all
        .where((i) => _kind.types == null || _kind.types!.contains(i.type))
        .where((i) => !_unfiledOnly || i.folderIds.isEmpty)
        .toList();

    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Everything saved', style: TwinsTypography.heading(palette.textPrimary)),
          actions: [
            IconButton(
              tooltip: 'Search',
              icon: const Icon(PhosphorIconsBold.magnifyingGlass),
              onPressed: () => context.push('/search'),
            ),
          ],
        ),
        bottomNavigationBar: _selected.isEmpty || space == null
            ? null
            : ItemSelectionBar(
                spaceId: space.id,
                items: all.where((i) => _selected.contains(i.id)).toList(),
                onDone: () {
                  if (mounted) setState(_selected.clear);
                },
              ),
        body: itemsAsync.isLoading && all.isEmpty
            ? Center(child: CircularProgressIndicator(color: context.twins.accent))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.lg),
                        children: [
                          for (final kind in _Kind.values) ...[
                            TwinsFilterChip(label: kind.label, selected: _kind == kind, onTap: () => setState(() => _kind = kind)),
                            const SizedBox(width: 6),
                          ],
                          TwinsFilterChip(
                            label: 'Not in a folder',
                            selected: _unfiledOnly,
                            onTap: () => setState(() => _unfiledOnly = !_unfiledOnly),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (shown.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(emoji: '📭', title: 'Nothing here yet'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.sm, TwinsSpacing.lg, TwinsSpacing.xxl),
                      sliver: SliverGrid.builder(
                        itemCount: shown.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: TwinsSpacing.sm,
                          crossAxisSpacing: TwinsSpacing.sm,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) {
                          final item = shown[index];
                          return ItemCard(
                            item: item,
                            selected: _selected.contains(item.id),
                            onTap: () => _selected.isEmpty ? context.push('/item/${item.id}') : _toggle(item.id),
                            onLongPress: () => _toggle(item.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
