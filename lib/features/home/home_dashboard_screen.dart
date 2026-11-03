import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/item.dart';
import '../../state/auth_providers.dart' show authStateProvider, currentSpaceProvider;
import '../../state/activity_provider.dart';
import '../../state/data_providers.dart';
import '../../state/greeting_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/event_card.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/item_card.dart';
import '../../widgets/filter_chip_twins.dart';
import '../../widgets/item_selection_bar.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/twins_logo.dart';
import '../folders/folder_dialogs.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  /// Long-press selection, shared by the Recently added strip and the
  /// Everything grid.
  final _selected = <String>{};
  bool _unfiledOnly = false;

  void _onItemTap(TwinsItem item) {
    if (_selected.isEmpty) {
      context.push('/item/${item.id}');
    } else {
      _toggle(item.id);
    }
  }

  /// Home shows a taste of Everything; the rest is on the Saved page.
  static const _homeGridLimit = 12;

  /// The next few plans, when there are any.
  List<Widget> _comingUp(String spaceId) {
    final upcoming = ref.watch(upcomingEventsProvider(spaceId)).take(3).toList();
    if (upcoming.isEmpty) return const [];
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    return [
      const SizedBox(height: TwinsSpacing.xl),
      Text('Coming up', style: TwinsTypography.heading(context.twins.textPrimary, size: 17)),
      const SizedBox(height: TwinsSpacing.sm),
      for (final event in upcoming)
        Padding(
          padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
          child: EventCard(
            event: event,
            accent: planAccent(event, myId),
            compact: true,
            onTap: () => context.push('/event/${event.id}'),
          ),
        ),
    ];
  }

  String _badgeLabel(int count) => count > 9 ? '9+' : '$count';

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  @override
  Widget build(BuildContext context) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    final palette = context.twins;
    final space = spaceAsync.valueOrNull;
    final allItems = space == null ? const <TwinsItem>[] : ref.watch(allItemsProvider(space.id)).valueOrNull ?? const <TwinsItem>[];

    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        bottomNavigationBar: _selected.isEmpty || space == null
            ? null
            : ItemSelectionBar(
                spaceId: space.id,
                items: allItems.where((i) => _selected.contains(i.id)).toList(),
                onDone: () {
                  if (mounted) setState(_selected.clear);
                },
              ),
        body: spaceAsync.when(
          data: (space) {
            if (space == null) {
              return const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen));
            }
            return SafeArea(
              child: RefreshIndicator(
                color: TwinsColors.mikuGreen,
                onRefresh: () async => ref.invalidate(currentSpaceProvider),
                child: ListView(
                  padding: const EdgeInsets.all(TwinsSpacing.lg),
                  children: [
                    Row(
                      children: [
                        TwinsLogo(size: 26, textColor: palette.textPrimary),
                        const Spacer(),
                        IconButton(
                          icon: Icon(PhosphorIconsBold.magnifyingGlass, color: palette.textPrimary),
                          onPressed: () => context.push('/search'),
                        ),
                        IconButton(
                          icon: Badge(
                            isLabelVisible: ref.watch(unreadActivityCountProvider(space.id)) > 0,
                            backgroundColor: TwinsColors.sakuraPink,
                            label: Text(_badgeLabel(ref.watch(unreadActivityCountProvider(space.id)))),
                            child: Icon(PhosphorIconsBold.bell, color: palette.textPrimary),
                          ),
                          onPressed: () => context.push('/activity'),
                        ),
                      ],
                    ),
                    if (ref.watch(showGreetingProvider)) ...[
                      const SizedBox(height: TwinsSpacing.md),
                      Text('Hey twins! 👋', style: TwinsTypography.heading(palette.textPrimary, size: 22)),
                      Text('What are we saving today?', style: TwinsTypography.body(palette.textSecondary)),
                    ],
                    ..._comingUp(space.id),
                    const SizedBox(height: TwinsSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Folders', style: TwinsTypography.heading(palette.textPrimary, size: 17)),
                        GestureDetector(
                          onTap: () => context.push('/folders'),
                          child: Text('See all', style: TwinsTypography.label(TwinsColors.mikuGreen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: TwinsSpacing.sm),
                    _FoldersGrid(spaceId: space.id),
                    const SizedBox(height: TwinsSpacing.xl),
                    Text('Recently added', style: TwinsTypography.heading(palette.textPrimary, size: 17)),
                    const SizedBox(height: TwinsSpacing.sm),
                    _RecentItemsStrip(spaceId: space.id, selected: _selected, onTap: _onItemTap, onLongPress: _toggle),
                    if (allItems.isNotEmpty) ...[
                      const SizedBox(height: TwinsSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Everything', style: TwinsTypography.heading(palette.textPrimary, size: 17)),
                          GestureDetector(
                            onTap: () => context.push('/saved'),
                            child: Text('See all', style: TwinsTypography.label(TwinsColors.mikuGreen)),
                          ),
                        ],
                      ),
                      const SizedBox(height: TwinsSpacing.sm),
                      Row(
                        children: [
                          TwinsFilterChip(label: 'All', selected: !_unfiledOnly, onTap: () => setState(() => _unfiledOnly = false)),
                          const SizedBox(width: 6),
                          TwinsFilterChip(
                            label: 'Not in a folder',
                            selected: _unfiledOnly,
                            onTap: () => setState(() => _unfiledOnly = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: TwinsSpacing.sm),
                      _EverythingGrid(
                        items: (_unfiledOnly ? allItems.where((i) => i.folderIds.isEmpty) : allItems).take(_homeGridLimit).toList(),
                        selected: _selected,
                        onTap: _onItemTap,
                        onLongPress: _toggle,
                      ),
                    ],
                    const SizedBox(height: TwinsSpacing.xxxl),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
          error: (e, _) => Center(child: Text('Something went wrong.', style: TwinsTypography.body(palette.textSecondary))),
        ),
      ),
    );
  }
}

/// Every item in the space, newest first, so the home screen doubles as a
/// place to sort things into folders (long-press to select).
class _EverythingGrid extends StatelessWidget {
  final List<TwinsItem> items;
  final Set<String> selected;
  final ValueChanged<TwinsItem> onTap;
  final ValueChanged<String> onLongPress;

  const _EverythingGrid({required this.items, required this.selected, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.xl),
        child: Text('Everything is in a folder ✨', textAlign: TextAlign.center, style: TwinsTypography.body(context.twins.textSecondary)),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: TwinsSpacing.sm,
        crossAxisSpacing: TwinsSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemCard(
          item: item,
          selected: selected.contains(item.id),
          onTap: () => onTap(item),
          onLongPress: () => onLongPress(item.id),
        );
      },
    );
  }
}

class _FoldersGrid extends ConsumerWidget {
  final String spaceId;
  const _FoldersGrid({required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider(FolderQuery(spaceId, null)));
    return foldersAsync.when(
      data: (folders) {
        final top = folders.take(5).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: top.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: TwinsSpacing.sm,
            crossAxisSpacing: TwinsSpacing.sm,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            if (index == top.length) {
              return AddFolderCard(onTap: () => showCreateFolderSheet(context, ref, spaceId: spaceId, parentId: null));
            }
            final folder = top[index];
            return FolderCard(
              folder: folder,
              onTap: () => context.push('/folder/${folder.id}'),
              onLongPress: () => showFolderOptionsSheet(context, ref, folder),
            );
          },
        );
      },
      loading: () => const FolderGridSkeleton(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _RecentItemsStrip extends ConsumerWidget {
  final String spaceId;
  final Set<String> selected;
  final ValueChanged<TwinsItem> onTap;
  final ValueChanged<String> onLongPress;
  const _RecentItemsStrip({required this.spaceId, required this.selected, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recentItemsProvider(spaceId));
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(emoji: '📥', title: 'Nothing here yet.', subtitle: 'Send something from TikTok, YouTube, or anywhere.');
        }
        return SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: TwinsSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 150,
                child: ItemCard(
                  item: item,
                  selected: selected.contains(item.id),
                  onTap: () => onTap(item),
                  onLongPress: () => onLongPress(item.id),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 216,
        child: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
