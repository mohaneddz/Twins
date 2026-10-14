import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../state/auth_providers.dart' show currentSpaceProvider;
import '../../state/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/item_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/twins_logo.dart';
import '../folders/folder_dialogs.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    final palette = context.twins;

    return Scaffold(
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
                        icon: Icon(PhosphorIconsBold.bell, color: palette.textPrimary),
                        onPressed: () => context.push('/activity'),
                      ),
                    ],
                  ),
                  const SizedBox(height: TwinsSpacing.md),
                  Text('Hey twins! 👋', style: TwinsTypography.heading(palette.textPrimary, size: 22)),
                  Text('What are we saving today?', style: TwinsTypography.body(palette.textSecondary)),
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
                  _RecentItemsStrip(spaceId: space.id),
                  const SizedBox(height: TwinsSpacing.xxxl),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
        error: (e, _) => Center(
          child: Text('Something went wrong.', style: TwinsTypography.body(palette.textSecondary)),
        ),
      ),
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
  const _RecentItemsStrip({required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recentItemsProvider(spaceId));
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            emoji: '📥',
            title: 'Nothing here yet.',
            subtitle: 'Send something from TikTok, YouTube, or anywhere.',
          );
        }
        return SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: TwinsSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(width: 150, child: ItemCard(item: item, onTap: () => context.push('/item/${item.id}')));
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 216, child: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen))),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
