import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/twins_logo.dart';

class PairingChoiceScreen extends StatelessWidget {
  const PairingChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.xl),
              const TwinsLogo(size: 36),
              const SizedBox(height: TwinsSpacing.sm),
              Text('One more step', style: TwinsTypography.heading(context.twins.textPrimary, size: 24)),
              const SizedBox(height: TwinsSpacing.xs),
              Text(
                'A Twins space is shared by exactly two people. Start a new one, or join your partner\'s.',
                style: TwinsTypography.body(context.twins.textSecondary),
              ),
              const SizedBox(height: TwinsSpacing.xxl),
              _ChoiceCard(
                icon: PhosphorIconsFill.plusCircle,
                title: 'Create our space',
                subtitle: "I'm starting fresh",
                onTap: () => context.push('/onboarding/create'),
              ),
              const SizedBox(height: TwinsSpacing.md),
              _ChoiceCard(
                icon: PhosphorIconsFill.linkSimple,
                title: 'Join with a code',
                subtitle: 'My partner already made one',
                onTap: () => context.push('/onboarding/join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TwinsRadius.lgRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TwinsSpacing.lg),
        decoration: BoxDecoration(
          color: TwinsColors.mikuMist,
          borderRadius: TwinsRadius.lgRadius,
        ),
        child: Row(
          children: [
            Icon(icon, color: TwinsColors.mikuGreen, size: 34),
            const SizedBox(width: TwinsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TwinsTypography.heading(context.twins.textPrimary, size: 17)),
                  Text(subtitle, style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight, color: TwinsColors.mikuGreen),
          ],
        ),
      ),
    );
  }
}
