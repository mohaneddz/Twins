import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_settings.dart';
import '../../state/auth_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends ConsumerState<NotificationsSettingsScreen> {
  TwinsUserSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = ref.read(authStateProvider).valueOrNull;
    if (me == null) return;
    final settings = await ref.read(repositoryProvider).getSettings(me.id);
    if (mounted) {
      setState(() {
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _update(bool enabled) async {
    final current = _settings;
    if (current == null) return;
    final updated = current.copyWith(notificationsEnabled: enabled);
    setState(() => _settings = updated);
    await ref.read(repositoryProvider).updateSettings(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen))
          : Padding(
              padding: const EdgeInsets.all(TwinsSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: TwinsRadius.lgRadius,
                    ),
                    child: SwitchListTile(
                      title: const Text('New activity'),
                      subtitle: const Text('New items, comments, and messages from your twin'),
                      value: _settings?.notificationsEnabled ?? true,
                      activeThumbColor: TwinsColors.mikuGreen,
                      onChanged: _update,
                    ),
                  ),
                  const SizedBox(height: TwinsSpacing.md),
                  Text(
                    'Push notifications require a device push token (APNs/FCM) which isn\'t configured in this build - '
                    'this toggle controls whether ¡Twins! would send them once that\'s set up. In-app, everything still '
                    'updates live via Realtime whether this is on or off.',
                    style: TwinsTypography.body(context.twins.textSecondary, size: 13),
                  ),
                ],
              ),
            ),
    );
  }
}
