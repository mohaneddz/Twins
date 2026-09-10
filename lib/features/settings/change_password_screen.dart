import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_input.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).updatePassword(password);
      if (mounted) {
        showTwinsToast(context, 'Password updated.');
        Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() => _error = "Couldn't update your password. Try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenHeader(title: 'Change password'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.lg),
              TwinsInput(hint: 'New password', controller: _password, obscure: true),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Confirm new password', controller: _confirm, obscure: true),
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.xs),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.lg),
              PrimaryButton(label: 'Update password', onPressed: _submit, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
