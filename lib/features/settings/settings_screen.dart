import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../state/repository_provider.dart';
import '../../state/theme_provider.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/toast.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(TwinsSpacing.lg),
        children: [
          const _SectionLabel('Account'),
          _SettingsGroup(children: [
            _SettingsTile(icon: PhosphorIconsRegular.userCircle, label: 'Edit profile', onTap: () => context.push('/settings/edit-profile')),
            _SettingsTile(icon: PhosphorIconsRegular.lock, label: 'Privacy', onTap: () => context.push('/settings/privacy')),
            _SettingsTile(icon: PhosphorIconsRegular.bell, label: 'Notifications', onTap: () => context.push('/settings/notifications')),
            _SettingsTile(
              icon: PhosphorIconsRegular.moon,
              label: 'Theme',
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (mode) {
                  if (mode != null) ref.read(themeModeProvider.notifier).setMode(mode);
                },
              ),
            ),
          ]),
          const SizedBox(height: TwinsSpacing.lg),
          const _SectionLabel('Our Space'),
          _SettingsGroup(children: [
            _SettingsTile(icon: PhosphorIconsRegular.folders, label: 'Manage folders', onTap: () => context.push('/settings/manage-folders')),
            _SettingsTile(icon: PhosphorIconsRegular.tag, label: 'Manage tags', onTap: () => context.push('/settings/manage-tags')),
            _SettingsTile(icon: PhosphorIconsRegular.userPlus, label: 'Invite / re-invite partner', onTap: () => context.push('/settings/invite')),
            _SettingsTile(
              icon: PhosphorIconsRegular.export,
              label: 'Export our space',
              onTap: () => _exportSpace(context, ref),
            ),
          ]),
          const SizedBox(height: TwinsSpacing.lg),
          const _SectionLabel('About'),
          _SettingsGroup(children: [
            _SettingsTile(icon: PhosphorIconsRegular.question, label: 'Help center', onTap: () => context.push('/settings/help')),
            _SettingsTile(icon: PhosphorIconsRegular.info, label: 'About ¡Twins!', onTap: () => _showAbout(context)),
            const _SettingsTile(icon: PhosphorIconsRegular.tag, label: 'Version', trailing: Text('1.0.0')),
          ]),
          const SizedBox(height: TwinsSpacing.xl),
          TextButton(
            onPressed: () async {
              final confirmed = await showConfirmDialog(context, title: 'Log out?', message: 'You can log back in anytime.', confirmLabel: 'Log out');
              if (confirmed) {
                await ref.read(repositoryProvider).logOut();
                if (context.mounted) context.go('/welcome');
              }
            },
            child: const Text('Log out', style: TextStyle(color: TwinsColors.danger, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: TwinsSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _exportSpace(BuildContext context, WidgetRef ref) async {
    final space = await ref.read(repositoryProvider).currentSpace();
    if (space == null) return;
    try {
      final data = await ref.read(repositoryProvider).exportSpace(space.id);
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${Directory.systemTemp.path}/twins-export-$stamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], subject: 'Our ¡Twins! space export');
    } catch (e) {
      if (context.mounted) showTwinsToast(context, "Couldn't export right now.", isError: true);
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: TwinsRadius.lgRadius),
        title: const Text('¡Twins!'),
        content: const Text('A private shared space for exactly two people. Everything we love, in one place, just for us.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwinsSpacing.xs, left: 4),
      child: Text(label, style: TwinsTypography.heading(Theme.of(context).colorScheme.onSurface, size: 15)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: TwinsRadius.lgRadius,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 52),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
