import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/twins_input.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenHeader(title: 'Reset password'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.lg),
              if (_sent) ...[
                Text(
                  "If an account exists for that email, we've sent a reset link.",
                  style: TwinsTypography.body(TwinsColors.mikuGreen),
                ),
              ] else ...[
                Text(
                  "Enter your email and we'll send you a link to reset your password.",
                  style: TwinsTypography.body(context.twins.textSecondary),
                ),
                const SizedBox(height: TwinsSpacing.lg),
                TwinsInput(hint: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: TwinsSpacing.lg),
                PrimaryButton(
                  label: 'Send reset link',
                  loading: _loading,
                  onPressed: () async {
                    setState(() => _loading = true);
                    try {
                      await ref.read(repositoryProvider).resetPassword(_email.text.trim());
                    } finally {
                      if (mounted) {
                        setState(() {
                          _loading = false;
                          _sent = true;
                        });
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
