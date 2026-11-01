import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/item.dart';
import '../features/folders/folder_dialogs.dart';
import '../state/repository_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'confirm_dialog.dart';
import 'toast.dart';

/// Bottom bar shown while items are long-press selected: file them into
/// folders, take them out of the folder being viewed, or delete them.
class ItemSelectionBar extends ConsumerWidget {
  final String spaceId;
  final List<TwinsItem> items;
  final VoidCallback onDone;

  /// The folder on screen, if any - enables "Remove from folder".
  final String? currentFolderId;

  const ItemSelectionBar({
    super.key,
    required this.spaceId,
    required this.items,
    required this.onDone,
    this.currentFolderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = currentFolderId;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.sm, vertical: TwinsSpacing.xs),
          child: Row(
            children: [
              const SizedBox(width: TwinsSpacing.xs),
              Text('${items.length} selected', style: TwinsTypography.label(Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              IconButton(
                tooltip: 'Add to folder',
                icon: const Icon(PhosphorIconsRegular.folderPlus),
                onPressed: () async {
                  await showAddToFolderSheet(context, ref, spaceId: spaceId, items: items);
                  onDone();
                },
              ),
              if (folderId != null)
                IconButton(
                  tooltip: 'Remove from this folder',
                  icon: const Icon(PhosphorIconsRegular.folderMinus),
                  onPressed: () async {
                    final repo = ref.read(repositoryProvider);
                    for (final item in items) {
                      await repo.setItemFolders(item.id, item.folderIds.where((id) => id != folderId).toList());
                    }
                    if (context.mounted) showTwinsToast(context, 'Removed from this folder');
                    onDone();
                  },
                ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: TwinsColors.danger),
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete ${items.length} ${items.length == 1 ? 'item' : 'items'}?',
                    message: 'This removes them for both of you. This cannot be undone.',
                  );
                  if (!confirmed) return;
                  final repo = ref.read(repositoryProvider);
                  for (final item in items) {
                    await repo.deleteItem(item.id);
                  }
                  onDone();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
