import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/folder.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';
import '../../widgets/twins_input.dart';

const _folderEmojis = ['📁', '😂', '✨', '🌍', '📦', '📚', '💚', '🎬', '🍔', '🏡'];

Future<void> showCreateFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required String? parentId,
}) async {
  final nameController = TextEditingController();
  var selectedColor = TwinsColors.folderPalette.first;
  var selectedIcon = _folderEmojis.first;

  await showTwinsBottomSheet(
    context: context,
    title: parentId == null ? 'New folder' : 'New subfolder',
    child: StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwinsInput(hint: 'Folder name', controller: nameController),
          const SizedBox(height: TwinsSpacing.md),
          Wrap(
            spacing: 10,
            children: _folderEmojis
                .map((e) => GestureDetector(
                      onTap: () => setState(() => selectedIcon = e),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: selectedIcon == e ? TwinsColors.mikuGreen.withValues(alpha: 0.25) : Colors.transparent,
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: TwinsSpacing.md),
          Wrap(
            spacing: 10,
            children: TwinsColors.folderPalette
                .map((c) => GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selectedColor == c ? Border.all(color: TwinsColors.navy, width: 2) : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: TwinsSpacing.lg),
          PrimaryButton(
            label: 'Create folder',
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await ref.read(repositoryProvider).createFolder(
                    spaceId: spaceId,
                    parentId: parentId,
                    name: nameController.text.trim(),
                    colorValue: selectedColor.toARGB32(),
                    icon: selectedIcon,
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
                showTwinsToast(context, 'Folder created ✨');
              }
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showRenameFolderSheet(BuildContext context, WidgetRef ref, TwinsFolder folder) async {
  final controller = TextEditingController(text: folder.name);
  await showTwinsBottomSheet(
    context: context,
    title: 'Rename folder',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TwinsInput(hint: 'Folder name', controller: controller),
        const SizedBox(height: TwinsSpacing.lg),
        PrimaryButton(
          label: 'Save',
          onPressed: () async {
            if (controller.text.trim().isEmpty) return;
            await ref.read(repositoryProvider).updateFolder(folder.copyWith(name: controller.text.trim()));
            ref.invalidate(folderByIdProvider(folder.id));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
}

/// Presents the space's folders and resolves to the chosen folder id (or null
/// if dismissed). [excludeFolderId] hides one folder (e.g. the current one).
Future<String?> showMoveToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  String spaceId, {
  String? excludeFolderId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final foldersAsync = ref.watch(foldersProvider(FolderQuery(spaceId, null)));
          return foldersAsync.when(
            data: (folders) {
              final choices = folders.where((f) => f.id != excludeFolderId).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(TwinsSpacing.md),
                    child: Text('Move to folder',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  if (choices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(TwinsSpacing.lg),
                      child: Text('No other folders yet.'),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: choices
                          .map((f) => ListTile(
                                leading: Text(f.icon, style: const TextStyle(fontSize: 22)),
                                title: Text(f.name),
                                onTap: () => Navigator.of(sheetContext).pop(f.id),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: TwinsSpacing.sm),
                ],
              );
            },
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

Future<void> showFolderOptionsSheet(BuildContext context, WidgetRef ref, TwinsFolder folder) async {
  await showTwinsBottomSheet(
    context: context,
    title: folder.name,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(folder.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
          title: Text(folder.isPinned ? 'Unpin folder' : 'Pin folder'),
          onTap: () async {
            await ref.read(repositoryProvider).updateFolder(folder.copyWith(isPinned: !folder.isPinned));
            ref.invalidate(folderByIdProvider(folder.id));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        ListTile(
          leading: const Icon(Icons.drive_file_rename_outline),
          title: const Text('Rename'),
          onTap: () {
            Navigator.of(context).pop();
            showRenameFolderSheet(context, ref, folder);
          },
        ),
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('New subfolder'),
          onTap: () {
            Navigator.of(context).pop();
            showCreateFolderSheet(context, ref, spaceId: folder.spaceId, parentId: folder.id);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: TwinsColors.danger),
          title: const Text('Delete folder', style: TextStyle(color: TwinsColors.danger)),
          onTap: () async {
            Navigator.of(context).pop();
            final confirmed = await showConfirmDialog(
              context,
              title: 'Delete "${folder.name}"?',
              message: 'This deletes the folder and everything inside it. This cannot be undone.',
            );
            if (confirmed) {
              await ref.read(repositoryProvider).deleteFolder(folder.id);
              if (context.mounted) {
                showTwinsToast(context, 'Folder deleted');
              }
            }
          },
        ),
      ],
    ),
  );
}
