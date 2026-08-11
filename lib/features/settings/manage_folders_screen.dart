import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/spacing.dart';
import '../../widgets/empty_state.dart';
import '../folders/folder_dialogs.dart';

class ManageFoldersScreen extends ConsumerWidget {
  const ManageFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage folders')),
      body: spaceAsync.when(
        data: (space) {
          if (space == null) return const SizedBox.shrink();
          final foldersAsync = ref.watch(foldersProvider(FolderQuery(space.id, null)));
          return foldersAsync.when(
            data: (folders) {
              if (folders.isEmpty) {
                return const EmptyState(emoji: '📁', title: 'No folders yet');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(TwinsSpacing.lg),
                itemCount: folders.length,
                separatorBuilder: (_, __) => const SizedBox(height: TwinsSpacing.xs),
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return ListTile(
                    leading: Text(folder.icon, style: const TextStyle(fontSize: 22)),
                    title: Text(folder.name),
                    subtitle: Text('${folder.itemCount} items'),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showFolderOptionsSheet(context, ref, folder),
                    ),
                    onTap: () => showFolderOptionsSheet(context, ref, folder),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
      ),
      floatingActionButton: spaceAsync.maybeWhen(
        data: (space) => space == null
            ? null
            : FloatingActionButton(
                onPressed: () => showCreateFolderSheet(context, ref, spaceId: space.id, parentId: null),
                child: const Icon(Icons.add),
              ),
        orElse: () => null,
      ),
    );
  }
}
