import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_client_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/twins_input.dart';
import '../../widgets/twins_logo.dart';

/// First-launch gate for a "normal" (no-embed) build: nothing works until
/// this device knows which Supabase project to talk to. A "special" build
/// (see scripts/build_special.ps1) skips this entirely - see
/// [isSpecialBuild] in supabase_client_provider.dart.
class SupabaseSetupScreen extends StatefulWidget {
  final VoidCallback onDone;

  const SupabaseSetupScreen({super.key, required this.onDone});

  @override
  State<SupabaseSetupScreen> createState() => _SupabaseSetupScreenState();
}

class _SupabaseSetupScreenState extends State<SupabaseSetupScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    final key = _key.text.trim();
    if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
      setState(() => _error = 'Enter your Supabase project URL (Project Settings → API).');
      return;
    }
    if (key.isEmpty) {
      setState(() => _error = 'Enter your Supabase publishable key.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fails fast with a clear error if the URL/key don't actually work,
      // rather than saving them and finding out on the next screen.
      await Supabase.initialize(url: url, publishableKey: key);
      await saveSupabaseConfig(url: url, publishableKey: key);
      widget.onDone();
    } catch (_) {
      setState(() => _error = "Couldn't connect. Double-check the URL and key.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwinsColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TwinsSpacing.xxl),
              const Center(child: TwinsLogo(size: 44)),
              const SizedBox(height: TwinsSpacing.lg),
              Text(
                'Connect your Supabase project',
                textAlign: TextAlign.center,
                style: TwinsTypography.heading(TwinsColors.white, size: 20),
              ),
              const SizedBox(height: TwinsSpacing.xs),
              Text(
                'This build has no project baked in. Paste your project URL and publishable key from Project Settings → API - this only happens once on this device.',
                textAlign: TextAlign.center,
                style: TwinsTypography.body(TwinsColors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: TwinsSpacing.xxl),
              TwinsInput(hint: 'https://xxxx.supabase.co', controller: _url, keyboardType: TextInputType.url),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'sb_publishable_...', controller: _key),
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.xs),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.lg),
              PrimaryButton(label: 'Connect', onPressed: _submit, loading: _loading),
              const SizedBox(height: TwinsSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
