import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/doodles.dart';
import '../../widgets/twins_input.dart';
import '../../widgets/twins_logo.dart';

class _AccountSlot {
  final String email;
  final String prefsKey;
  final String defaultLabel;

  const _AccountSlot({required this.email, required this.prefsKey, required this.defaultLabel});
}

/// Fixed two-person membership: this app only ever has these two accounts.
/// The display label next to each is purely local (stored on-device) so
/// either person can rename their own slot without touching the account.
const _slots = [
  _AccountSlot(email: 'mohaned@twins.app', prefsKey: 'twins_slot1_label', defaultLabel: 'User 1'),
  _AccountSlot(email: 'rania@twins.app', prefsKey: 'twins_slot2_label', defaultLabel: 'User 2'),
];

class UserPickerScreen extends ConsumerStatefulWidget {
  const UserPickerScreen({super.key});

  @override
  ConsumerState<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends ConsumerState<UserPickerScreen> {
  final _password = TextEditingController();
  List<String> _labels = _slots.map((s) => s.defaultLabel).toList();
  int? _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _labels = [for (final slot in _slots) prefs.getString(slot.prefsKey) ?? slot.defaultLabel];
    });
  }

  Future<void> _rename(int index) async {
    final controller = TextEditingController(text: _labels[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_slots[index].prefsKey, result);
    if (!mounted) return;
    setState(() => _labels[index] = result);
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _error = null;
      _password.clear();
    });
  }

  Future<void> _submit() async {
    final index = _selected;
    if (index == null) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).logIn(email: _slots[index].email, password: _password.text);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't log in. Check the password.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DoodleField()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: TwinsSpacing.xxl),
                  const TwinsLogo(size: 48),
                  const SizedBox(height: TwinsSpacing.sm),
                  Text("Who's this? 💚", style: TwinsTypography.body(TwinsColors.mikuGreen, size: 16)),
                  const SizedBox(height: TwinsSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slots.length; i++) ...[
                        if (i > 0) const SizedBox(width: TwinsSpacing.xl),
                        _ProfileCard(
                          label: _labels[i],
                          selected: selected == i,
                          onTap: () => _select(i),
                          onRename: () => _rename(i),
                        ),
                      ],
                    ],
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: TwinsSpacing.xxl),
                    TwinsInput(hint: 'Password for ${_labels[selected]}', controller: _password, obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: TwinsSpacing.xs),
                      Text(_error!, style: const TextStyle(color: TwinsColors.danger, fontSize: 13)),
                    ],
                    const SizedBox(height: TwinsSpacing.md),
                    PrimaryButton(label: 'Log in', onPressed: _submit, loading: _loading),
                    const SizedBox(height: TwinsSpacing.xs),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                  const SizedBox(height: TwinsSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _ProfileCard({required this.label, required this.selected, required this.onTap, required this.onRename});

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
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
              gradient: const LinearGradient(colors: [TwinsColors.mikuLight, TwinsColors.vibrantBlue]),
              border: Border.all(color: selected ? TwinsColors.mikuGreen : Colors.transparent, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: TwinsTypography.heading(TwinsColors.white, size: 32)),
          ),
          const SizedBox(height: TwinsSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TwinsTypography.label(context.twins.textPrimary)),
              GestureDetector(
                onTap: onRename,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(PhosphorIconsRegular.pencilSimple, size: 14, color: context.twins.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
