import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/twins_input.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty) {
      setState(() => _error = 'Tell us what to call you.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).signUp(email: email, password: password, displayName: name);
      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't create your account. Try a different email.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenHeader(title: 'Create account'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.lg),
              Text('just for us, always private 💚', style: TwinsTypography.body(TwinsColors.mikuGreen)),
              const SizedBox(height: TwinsSpacing.xl),
              TwinsInput(hint: 'Your name', controller: _name),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Password', controller: _password, obscure: true),
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.xs),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.lg),
              PrimaryButton(label: 'Create account', onPressed: _submit, loading: _loading),
              const SizedBox(height: TwinsSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
