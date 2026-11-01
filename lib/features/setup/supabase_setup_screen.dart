import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/supabase/project_setup.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/twins_input.dart';
import '../../widgets/twins_logo.dart';

enum _Step { connect, install, functions }

/// First-launch setup: connect to a Supabase project, install or update its
/// database if needed, and optionally deploy the edge functions behind link
/// previews and AI. Admin credentials asked for along the way are used once
/// and never saved; only the project URL and publishable key are kept.
class SupabaseSetupScreen extends StatefulWidget {
  final Future<void> Function() onDone;

  const SupabaseSetupScreen({super.key, required this.onDone});

  @override
  State<SupabaseSetupScreen> createState() => _SupabaseSetupScreenState();
}

class _SupabaseSetupScreenState extends State<SupabaseSetupScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _connectionString = TextEditingController();
  final _accessToken = TextEditingController();
  final _groqKey = TextEditingController();

  _Step _step = _Step.connect;
  ProjectStatus? _status;
  bool _loading = false;
  String? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    knownSupabaseConfig.then((config) {
      if (!mounted) return;
      _url.text = config.url;
      _key.text = config.publishableKey;
      // Known project (special build, or an app update): check it right away.
      if (config.url.isNotEmpty && config.publishableKey.isNotEmpty) _connect();
    });
  }

  @override
  void dispose() {
    for (final c in [_url, _key, _connectionString, _accessToken, _groqKey]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _projectUrl => _url.text.trim().replaceAll(RegExp(r'/+$'), '');

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await task();
    } on SetupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _connect() => _run(() async {
        final url = _projectUrl;
        if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
          throw const SetupException('Enter your project URL, like https://abcd.supabase.co');
        }
        if (_key.text.trim().isEmpty) throw const SetupException('Paste the publishable key too.');
        _status = await probeProject(url, _key.text.trim());
        _advance();
      });

  Future<void> _install() => _run(() async {
        await installSchema(_connectionString.text, onStep: (step) => setState(() => _progress = 'Setting up $step…'));
        _connectionString.clear();
        _status = await probeProject(_projectUrl, _key.text.trim());
        if (!_status!.schemaReady) {
          throw const SetupException('The install finished but the database still reports an old version.');
        }
        _advance();
      });

  Future<void> _deploy() => _run(() async {
        if (_accessToken.text.trim().isEmpty) throw const SetupException('Paste an access token, or skip this step.');
        await deployEdgeFunctions(
          projectUrl: _projectUrl,
          accessToken: _accessToken.text,
          groqApiKey: _groqKey.text,
          onStep: (step) => setState(() => _progress = 'Deploying $step…'),
        );
        _accessToken.clear();
        _groqKey.clear();
        await _finish();
      });

  void _advance() {
    final status = _status!;
    if (!status.schemaReady) {
      setState(() => _step = _Step.install);
    } else if (status.missingFunctions.isNotEmpty) {
      setState(() => _step = _Step.functions);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await completeSetup(url: _projectUrl, publishableKey: _key.text.trim());
    await widget.onDone();
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
              ...switch (_step) {
                _Step.connect => _connectStep(),
                _Step.install => _installStep(),
                _Step.functions => _functionsStep(),
              },
              if (_progress != null) ...[
                const SizedBox(height: TwinsSpacing.sm),
                Text(_progress!, textAlign: TextAlign.center, style: TwinsTypography.body(TwinsColors.mikuLight, size: 13)),
              ],
              if (_error != null) ...[
                const SizedBox(height: TwinsSpacing.sm),
                Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: TwinsSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _connectStep() => [
        _title('Connect your Supabase project'),
        _subtitle(
          'Both twins use the same project. Find these in your Supabase dashboard → Project Settings → API Keys.',
        ),
        const SizedBox(height: TwinsSpacing.xxl),
        _label('Project URL'),
        TwinsInput(hint: 'https://xxxx.supabase.co', controller: _url, keyboardType: TextInputType.url),
        const SizedBox(height: TwinsSpacing.md),
        _label('Publishable key'),
        TwinsInput(hint: 'sb_publishable_…', controller: _key),
        const SizedBox(height: TwinsSpacing.lg),
        PrimaryButton(label: 'Connect', onPressed: _connect, loading: _loading),
        const SizedBox(height: TwinsSpacing.md),
        _link('New to Supabase? Create a free project', 'https://supabase.com/dashboard/new'),
      ];

  List<Widget> _installStep() => [
        _title(_status!.schemaVersion == 0 ? 'Set up the database' : 'Update the database'),
        _subtitle(
          _status!.schemaVersion == 0
              ? 'This project is empty. Paste its database connection string once and ¡Twins! creates everything it needs.'
              : 'This version of ¡Twins! needs a few database changes. Paste the connection string once to apply them.',
        ),
        const SizedBox(height: TwinsSpacing.lg),
        _hint('Dashboard → Connect (top bar) → Session pooler → copy the URI, and replace [YOUR-PASSWORD] with your database password. '
            'It\'s only used for this step and is never saved.'),
        const SizedBox(height: TwinsSpacing.md),
        _label('Connection string'),
        TwinsInput(hint: 'postgresql://postgres.xxxx:password@…pooler.supabase.com:5432/postgres', controller: _connectionString),
        const SizedBox(height: TwinsSpacing.lg),
        PrimaryButton(label: 'Set up', onPressed: _install, loading: _loading),
        const SizedBox(height: TwinsSpacing.sm),
        _back(),
      ];

  List<Widget> _functionsStep() => [
        _title('Link previews & AI'),
        _subtitle(
          'Optional. Deploys the three small server functions that fetch link previews, suggest tags and name chats. '
          'Without them ¡Twins! still works, links just save without a preview.',
        ),
        const SizedBox(height: TwinsSpacing.lg),
        _hint('Create an access token at supabase.com/dashboard/account/tokens. A Groq key (console.groq.com/keys) turns on the AI parts. '
            'Neither is saved on this phone.'),
        const SizedBox(height: TwinsSpacing.md),
        _label('Supabase access token'),
        TwinsInput(hint: 'sbp_…', controller: _accessToken),
        const SizedBox(height: TwinsSpacing.md),
        _label('Groq API key (optional)'),
        TwinsInput(hint: 'gsk_…', controller: _groqKey),
        const SizedBox(height: TwinsSpacing.lg),
        PrimaryButton(label: 'Deploy', onPressed: _deploy, loading: _loading),
        const SizedBox(height: TwinsSpacing.sm),
        SecondaryButton(label: 'Skip for now', onPressed: _loading ? null : _finish),
      ];

  Widget _title(String text) =>
      Text(text, textAlign: TextAlign.center, style: TwinsTypography.heading(TwinsColors.white, size: 20));

  Widget _subtitle(String text) => Padding(
        padding: const EdgeInsets.only(top: TwinsSpacing.xs),
        child: Text(text, textAlign: TextAlign.center, style: TwinsTypography.body(TwinsColors.white.withValues(alpha: 0.7))),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: TwinsSpacing.xs),
        child: Text(text, style: TwinsTypography.label(TwinsColors.white.withValues(alpha: 0.85))),
      );

  Widget _hint(String text) => Container(
        padding: const EdgeInsets.all(TwinsSpacing.md),
        decoration: BoxDecoration(
          color: TwinsColors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: TwinsTypography.body(TwinsColors.white.withValues(alpha: 0.75), size: 13)),
      );

  Widget _link(String text, String url) => TextButton(
        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(text, style: TwinsTypography.label(TwinsColors.mikuLight)),
      );

  Widget _back() => TextButton(
        onPressed: _loading ? null : () => setState(() => _step = _Step.connect),
        child: Text('Use a different project', style: TwinsTypography.label(TwinsColors.white.withValues(alpha: 0.6))),
      );
}
