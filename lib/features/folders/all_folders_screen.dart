import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/skeletons.dart';
import 'folder_dialogs.dart';

class AllFoldersScreen extends ConsumerWidget {
  const AllFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Our folders', style: TwinsTypography.heading(context.twins.textPrimary)),
      ),
      body: spaceAsync.when(
        data: (space) {
          if (space == null) return const SizedBox.shrink();
          final foldersAsync = ref.watch(foldersProvider(FolderQuery(space.id, null)));
          return foldersAsync.when(
            data: (folders) {
              if (folders.isEmpty) {
                return EmptyState(
                  emoji: '📁',
                  title: 'No folders yet',
                  subtitle: 'Make a little corner for your stuff ✨',
                  action: FilledButton(
                    onPressed: () => showCreateFolderSheet(context, ref, spaceId: space.id, parentId: null),
                    child: const Text('New folder'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(TwinsSpacing.lg),
                child: GridView.builder(
                  itemCount: folders.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: TwinsSpacing.sm,
                    crossAxisSpacing: TwinsSpacing.sm,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    if (index == folders.length) {
                      return AddFolderCard(onTap: () => showCreateFolderSheet(context, ref, spaceId: space.id, parentId: null));
                    }
                    final folder = folders[index];
                    return FolderCard(
                      folder: folder,
                      onTap: () => context.push('/folder/${folder.id}'),
                      onLongPress: () => showFolderOptionsSheet(context, ref, folder),
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(padding: EdgeInsets.all(TwinsSpacing.lg), child: FolderGridSkeleton()),
            error: (e, _) => const SizedBox.shrink(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }
}
