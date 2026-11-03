import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/twin_slot.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/doodles.dart';
import '../../widgets/twins_input.dart';
import '../../widgets/twins_logo.dart';

/// "Who's this?": the project's two account slots. A taken slot logs in with
/// its password; an empty one is created right here with a name and password.
class UserPickerScreen extends ConsumerStatefulWidget {
  const UserPickerScreen({super.key});

  @override
  ConsumerState<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends ConsumerState<UserPickerScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late Future<List<TwinSlot>> _slots = ref.read(repositoryProvider).twinSlots();
  int? _selected;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _select(int slot) {
    setState(() {
      _selected = slot;
      _error = null;
      _name.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  Future<void> _logIn(TwinSlot slot) async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the password.');
      return;
    }
    await _submit(() => ref.read(repositoryProvider).logIn(email: slot.loginEmail, password: _password.text),
        failure: "Wrong password for ${slot.displayName}.");
  }

  Future<void> _create(int slot) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "What's your name?");
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Use at least 6 characters for the password.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "The passwords don't match.");
      return;
    }
    await _submit(
      () => ref.read(repositoryProvider).claimTwinSlot(slot: slot, displayName: _name.text.trim(), password: _password.text),
      failure: "Couldn't create the account.",
    );
  }

  Future<void> _submit(Future<void> Function() action, {required String failure}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) context.go('/home');
    } on PostgrestException catch (e) {
      // Raised by claim_twin_slot with a message meant for people, e.g. the
      // other phone created this twin a moment ago.
      if (mounted) {
        setState(() {
          _error = e.message;
          _slots = ref.read(repositoryProvider).twinSlots();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _forgotPassword(TwinSlot slot) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot your password?'),
        content: Text(
          "There's no recovery email in ¡Twins!. Ask your twin to open Settings → Privacy → "
          "Reset a twin's password and set a new one for ${slot.displayName}.",
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DoodleField()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
              child: FutureBuilder<List<TwinSlot>>(
                future: _slots,
                builder: (context, snapshot) => Column(
                  children: [
                    const SizedBox(height: TwinsSpacing.xxl),
                    const TwinsLogo(size: 48),
                    const SizedBox(height: TwinsSpacing.sm),
                    Text("Who's this? 💚", style: TwinsTypography.body(context.twins.accent, size: 16)),
                    const SizedBox(height: TwinsSpacing.xxl),
                    if (snapshot.hasError)
                      _loadError()
                    else if (!snapshot.hasData)
                      const Padding(padding: EdgeInsets.all(TwinsSpacing.xl), child: CircularProgressIndicator())
                    else
                      ..._picker(snapshot.data!),
                    const SizedBox(height: TwinsSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadError() => Column(
        children: [
          Text("Couldn't reach your project.", style: TwinsTypography.body(context.twins.textSecondary)),
          TextButton(
            onPressed: () => setState(() => _slots = ref.read(repositoryProvider).twinSlots()),
            child: const Text('Try again'),
          ),
        ],
      );

  List<Widget> _picker(List<TwinSlot> taken) {
    TwinSlot? find(int slot) => taken.where((s) => s.slot == slot).firstOrNull;
    final selected = _selected;
    final selectedTwin = selected == null ? null : find(selected);
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final slot in [1, 2]) ...[
            if (slot == 2) const SizedBox(width: TwinsSpacing.xl),
            _ProfileCard(twin: find(slot), slot: slot, selected: selected == slot, onTap: () => _select(slot)),
          ],
        ],
      ),
      if (taken.isEmpty) ...[
        const SizedBox(height: TwinsSpacing.lg),
        Text(
          'Brand new space! Tap a bubble to create your account - your twin takes the other one on their phone.',
          textAlign: TextAlign.center,
          style: TwinsTypography.body(context.twins.textSecondary, size: 13),
        ),
      ],
      if (selected != null) ...[
        const SizedBox(height: TwinsSpacing.xxl),
        if (selectedTwin != null) ...[
          TwinsInput(hint: 'Password for ${selectedTwin.displayName}', controller: _password, obscure: true),
        ] else ...[
          TwinsInput(hint: 'Your name', controller: _name),
          const SizedBox(height: TwinsSpacing.sm),
          TwinsInput(hint: 'Choose a password', controller: _password, obscure: true),
          const SizedBox(height: TwinsSpacing.sm),
          TwinsInput(hint: 'Password again', controller: _confirm, obscure: true),
        ],
        if (_error != null) ...[
          const SizedBox(height: TwinsSpacing.xs),
          Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: TwinsSpacing.md),
        PrimaryButton(
          label: selectedTwin != null ? 'Log in' : 'Create account',
          onPressed: selectedTwin != null ? () => _logIn(selectedTwin) : () => _create(selected),
          loading: _loading,
        ),
        if (selectedTwin != null) ...[
          const SizedBox(height: TwinsSpacing.xs),
          TextButton(onPressed: () => _forgotPassword(selectedTwin), child: const Text('Forgot password?')),
        ],
      ],
    ];
  }
}

class _ProfileCard extends StatelessWidget {
  final TwinSlot? twin;
  final int slot;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileCard({required this.twin, required this.slot, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final twin = this.twin;
    final avatarUrl = twin?.avatarUrl;
    final name = twin?.displayName.trim() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: twin == null ? null : LinearGradient(colors: [context.twins.accentLight, TwinsColors.vibrantBlue]),
              color: twin == null ? context.twins.textSecondary.withValues(alpha: 0.12) : null,
              border: Border.all(color: selected ? context.twins.accent : Colors.transparent, width: 3),
              image: avatarUrl == null
                  ? null
                  : DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: twin == null
                ? Icon(PhosphorIconsRegular.plus, size: 30, color: context.twins.textSecondary)
                : avatarUrl == null
                    ? Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TwinsTypography.heading(TwinsColors.white, size: 32))
                    : null,
          ),
          const SizedBox(height: TwinsSpacing.xs),
          Text(
            twin == null ? 'Twin $slot' : name,
            style: TwinsTypography.label(twin == null ? context.twins.textSecondary : context.twins.textPrimary),
          ),
        ],
      ),
    );
  }
}
