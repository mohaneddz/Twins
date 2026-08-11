import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/auth_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/toast.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(TwinsSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(TwinsSpacing.lg),
            decoration: BoxDecoration(color: TwinsColors.mikuMist, borderRadius: TwinsRadius.lgRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Just for us, always private 💚', style: TwinsTypography.heading(context.twins.textPrimary, size: 17)),
                const SizedBox(height: TwinsSpacing.sm),
                Text(
                  'Every folder, item, comment, and message in ¡Twins! is only visible to the two people '
                  'in this space. There is no public profile, no discovery feed, and no way for anyone else '
                  'to see or search your content - this is enforced on the server (Row Level Security), not '
                  'just hidden in the app.',
                  style: TwinsTypography.body(context.twins.textPrimary.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: TwinsSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: TwinsRadius.lgRadius,
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: TwinsColors.danger),
              title: const Text('Leave this space', style: TextStyle(color: TwinsColors.danger)),
              subtitle: const Text('You\'ll need a new invite code to rejoin'),
              onTap: () => _leaveSpace(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveSpace(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave this Twins space?',
      message: "You'll lose access to everything in it until you rejoin with a new invite code.",
      confirmLabel: 'Leave',
    );
    if (!confirmed) return;
    final space = await ref.read(repositoryProvider).currentSpace();
    if (space == null) return;
    await ref.read(repositoryProvider).leaveSpace(space.id);
    ref.invalidate(currentSpaceProvider);
    if (context.mounted) {
      showTwinsToast(context, 'You left the space.');
      context.go('/onboarding');
    }
  }
}
