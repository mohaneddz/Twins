import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/twins_input.dart';

class JoinSpaceScreen extends ConsumerStatefulWidget {
  const JoinSpaceScreen({super.key});

  @override
  ConsumerState<JoinSpaceScreen> createState() => _JoinSpaceScreenState();
}

class _JoinSpaceScreenState extends ConsumerState<JoinSpaceScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Enter the invite code your partner sent you.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).joinSpaceWithCode(code);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = "That code didn't work. Double-check it and try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenHeader(title: 'Join with a code'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.lg),
              Text('Enter the 6-character code your partner shared with you.',
                  style: TwinsTypography.body(context.twins.textSecondary)),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'e.g. 7HG2K9', controller: _code),
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.xs),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.lg),
              PrimaryButton(label: 'Join space', onPressed: _join, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
