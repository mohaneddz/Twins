import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/twins_input.dart';
import '../../widgets/twins_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).logIn(email: email, password: password);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Couldn't log in. Check your email and password.");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.xxl),
              const Center(child: TwinsLogo(size: 44)),
              const SizedBox(height: TwinsSpacing.sm),
              Center(
                child: Text('Welcome back 💚', style: TwinsTypography.body(TwinsColors.mikuGreen, size: 16)),
              ),
              const SizedBox(height: TwinsSpacing.xxl),
              TwinsInput(hint: 'Email', controller: _email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Password', controller: _password, obscure: true),
              const SizedBox(height: TwinsSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.xs),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.md),
              PrimaryButton(label: 'Log in', onPressed: _submit, loading: _loading),
              const SizedBox(height: TwinsSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: TwinsTypography.body(context.twins.textSecondary)),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: Text('Create one', style: TwinsTypography.label(TwinsColors.mikuGreen)),
                  ),
                ],
              ),
              const SizedBox(height: TwinsSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
