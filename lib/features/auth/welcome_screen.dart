import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/doodles.dart';
import '../../widgets/twins_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DoodleField()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  const TwinsLogo(size: 56),
                  const SizedBox(height: TwinsSpacing.lg),
                  Text(
                    'Everything we love,\nin one private place.\nJust for two. 💗',
                    textAlign: TextAlign.center,
                    style: TwinsTypography.heading(TwinsColors.mikuGreen, size: 20),
                  ),
                  const Spacer(flex: 4),
                  PrimaryButton(label: 'Log in', onPressed: () => context.push('/login')),
                  const SizedBox(height: TwinsSpacing.md),
                  SecondaryButton(label: 'Create account', onPressed: () => context.push('/signup')),
                  const SizedBox(height: TwinsSpacing.xl),
                  Text(
                    'just for us. always private.',
                    style: TwinsTypography.body(TwinsColors.mikuGreen.withValues(alpha: 0.7), size: 13),
                  ),
                  const SizedBox(height: TwinsSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
