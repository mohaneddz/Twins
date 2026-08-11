import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/space.dart';
import '../../state/auth_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';

class InvitePartnerScreen extends ConsumerStatefulWidget {
  const InvitePartnerScreen({super.key});

  @override
  ConsumerState<InvitePartnerScreen> createState() => _InvitePartnerScreenState();
}

class _InvitePartnerScreenState extends ConsumerState<InvitePartnerScreen> {
  SpaceInvite? _invite;
  bool _loading = false;

  Future<void> _generate() async {
    final space = await ref.read(currentSpaceProvider.future);
    if (space == null) return;
    setState(() => _loading = true);
    final invite = await ref.read(repositoryProvider).createInvite(space.id);
    if (mounted) {
      setState(() {
        _invite = invite;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite your twin')),
      body: Padding(
        padding: const EdgeInsets.all(TwinsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Share this code so your partner can join your space.', style: TwinsTypography.body(context.twins.textSecondary)),
            const SizedBox(height: TwinsSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.xl),
              decoration: BoxDecoration(color: TwinsColors.mikuMist, borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator(color: TwinsColors.mikuGreen)
                  : Text(_invite?.code ?? '------', style: TwinsTypography.display(TwinsColors.mikuGreen, size: 40)),
            ),
            const SizedBox(height: TwinsSpacing.md),
            if (_invite != null)
              Text('Expires ${_invite!.expiresAt.month}/${_invite!.expiresAt.day}', style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
            const SizedBox(height: TwinsSpacing.xl),
            PrimaryButton(
              label: 'Share invite',
              onPressed: _invite == null ? null : () => Share.share('Join our ¡Twins! space with code ${_invite!.code}'),
            ),
            const SizedBox(height: TwinsSpacing.sm),
            OutlinedButton(onPressed: _generate, child: const Text('Generate new code')),
          ],
        ),
      ),
    );
  }
}
