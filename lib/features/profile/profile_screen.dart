import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/item_type.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/avatars.dart';
import '../../widgets/buttons.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    final palette = context.twins;
    return Scaffold(
      body: SafeArea(
        child: spaceAsync.when(
          data: (space) {
            if (space == null) return const SizedBox.shrink();
            final membersAsync = ref.watch(spaceMembersProvider(space.id));
            final foldersAsync = ref.watch(foldersProvider(FolderQuery(space.id, null)));
            final itemsAsync = ref.watch(allItemsProvider(space.id));
            final chatsAsync = ref.watch(chatsProvider(space.id));

            final folderCount = foldersAsync.valueOrNull?.length ?? 0;
            final itemCount = itemsAsync.valueOrNull?.length ?? 0;
            final noteCount = itemsAsync.valueOrNull?.where((i) => i.type == ItemType.note).length ?? 0;
            final chatCount = chatsAsync.valueOrNull?.length ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(TwinsSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(icon: Icon(PhosphorIconsBold.caretLeft, color: palette.textPrimary), onPressed: () => context.pop()),
                      const Spacer(),
                      IconButton(
                        icon: Icon(PhosphorIconsBold.gearSix, color: palette.textPrimary),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  membersAsync.when(
                    data: (members) => members.length >= 2
                        ? TwinAvatars(a: members[0], b: members[1])
                        : (members.isNotEmpty ? UserAvatar(profile: members.first, size: 90) : const SizedBox(height: 90)),
                    loading: () => const SizedBox(height: 90),
                    error: (e, _) => const SizedBox(height: 90),
                  ),
                  const SizedBox(height: TwinsSpacing.md),
                  Text("¡We're Twins! 💚", style: TwinsTypography.heading(palette.textPrimary, size: 24)),
                  const SizedBox(height: 4),
                  Text('Joined ${_formatDate(space.createdAt)}', style: TwinsTypography.body(palette.textSecondary)),
                  const SizedBox(height: TwinsSpacing.xl),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.md),
                    decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        _Stat(label: 'Folders', value: folderCount),
                        _Stat(label: 'Items', value: itemCount),
                        _Stat(label: 'Notes', value: noteCount),
                        _Stat(label: 'Chats', value: chatCount),
                      ],
                    ),
                  ),
                  const SizedBox(height: TwinsSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(TwinsSpacing.lg),
                    decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About our space', style: TwinsTypography.heading(palette.textPrimary, size: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'A private little corner of the internet for everything we love.\nMemories, ideas, chaos, everything. ✨',
                          style: TwinsTypography.body(palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TwinsSpacing.xl),
                  PrimaryButton(label: 'Edit profile', onPressed: () => context.push('/settings/edit-profile')),
                  const SizedBox(height: TwinsSpacing.xxl),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TwinsTypography.heading(context.twins.textPrimary, size: 22)),
          Text(label, style: TwinsTypography.body(context.twins.textSecondary, size: 12)),
        ],
      ),
    );
  }
}
