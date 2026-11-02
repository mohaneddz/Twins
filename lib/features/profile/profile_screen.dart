import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/item_type.dart';
import '../../data/models/profile.dart';
import '../../sharing/twin_invite.dart';
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
            final members = membersAsync.valueOrNull ?? const <Profile>[];
            final myId = ref.watch(authStateProvider).valueOrNull?.id;
            // From the live members stream, so edits (yours or your twin's)
            // show up without a refresh.
            final me = members.where((m) => m.id == myId).firstOrNull;
            final twin = members.where((m) => m.id != myId).firstOrNull;

            return RefreshIndicator(
              color: TwinsColors.mikuGreen,
              onRefresh: () async {
                ref.invalidate(spaceMembersProvider(space.id));
                ref.invalidate(foldersProvider(FolderQuery(space.id, null)));
                ref.invalidate(allItemsProvider(space.id));
                ref.invalidate(chatsProvider(space.id));
                await ref.read(spaceMembersProvider(space.id).future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(TwinsSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(PhosphorIconsBold.caretLeft, color: palette.textPrimary),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(PhosphorIconsBold.gearSix, color: palette.textPrimary),
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                    if (me != null) ...[
                      UserAvatar(profile: me, size: 96),
                      const SizedBox(height: TwinsSpacing.md),
                      Text(me.displayName, style: TwinsTypography.heading(palette.textPrimary, size: 24)),
                      Text('@${me.username}', style: TwinsTypography.body(TwinsColors.mikuGreen)),
                      if ((me.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: TwinsSpacing.xs),
                        Text(me.bio!, textAlign: TextAlign.center, style: TwinsTypography.body(palette.textSecondary)),
                      ],
                      const SizedBox(height: 4),
                      Text('Joined ${formatDate(me.createdAt)}', style: TwinsTypography.label(palette.textSecondary, size: 12)),
                    ],
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
                    _TwinCard(twin: twin, loaded: membersAsync.hasValue),
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
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  static String formatDate(DateTime dt) {
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

/// The other twin's profile, or an invite while their slot is still empty.
class _TwinCard extends StatelessWidget {
  final Profile? twin;
  final bool loaded;
  const _TwinCard({required this.twin, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final twin = this.twin;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TwinsSpacing.lg),
      decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your twin', style: TwinsTypography.heading(palette.textPrimary, size: 16)),
          const SizedBox(height: TwinsSpacing.sm),
          if (twin != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(profile: twin, size: 56),
                const SizedBox(width: TwinsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(twin.displayName, style: TwinsTypography.heading(palette.textPrimary, size: 17)),
                      Text('@${twin.username}', style: TwinsTypography.body(TwinsColors.mikuGreen, size: 14)),
                      const SizedBox(height: 4),
                      Text(
                        (twin.bio ?? '').isNotEmpty ? twin.bio! : 'No bio yet',
                        style: TwinsTypography.body(palette.textSecondary, size: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Joined ${ProfileScreen.formatDate(twin.createdAt)}',
                        style: TwinsTypography.label(palette.textSecondary, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else if (loaded) ...[
            Text("Your twin hasn't joined yet.", style: TwinsTypography.body(palette.textSecondary)),
            const SizedBox(height: TwinsSpacing.sm),
            SecondaryButton(label: 'Send them an invite', onPressed: shareTwinInvite),
          ],
        ],
      ),
    );
  }
}
