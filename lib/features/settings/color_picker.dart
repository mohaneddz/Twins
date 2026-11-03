import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/profile.dart';
import '../../state/auth_providers.dart';
import '../../state/repository_provider.dart';
import '../../state/twin_color_provider.dart';
import '../../theme/palette.dart';
import '../../theme/spacing.dart';
import '../../theme/twin_color.dart';
import '../../theme/typography.dart';
import '../../widgets/toast.dart';

/// Settings → Our colours: pick mine (the whole app and its icon follow), and
/// see which one my twin is shown in.
class TwinColorPicker extends ConsumerWidget {
  const TwinColorPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.twins;
    final mine = ref.watch(myColorProvider);
    final me = ref.watch(authStateProvider).valueOrNull;
    final space = ref.watch(currentSpaceProvider).valueOrNull;
    final members = space == null ? const <Profile>[] : ref.watch(spaceMembersProvider(space.id)).valueOrNull ?? const <Profile>[];
    final twin = members.where((m) => m.id != me?.id).firstOrNull;
    final twinColor = twin == null ? null : ref.watch(colorOfUserProvider(twin.id));

    return Padding(
      padding: const EdgeInsets.all(TwinsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My colour', style: TwinsTypography.label(palette.textPrimary)),
          const SizedBox(height: 2),
          Text('The whole app and its icon on this phone. Your twin sees your stuff in it.',
              style: TwinsTypography.body(palette.textSecondary, size: 12.5)),
          const SizedBox(height: TwinsSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final color in TwinColor.values)
                _Swatch(
                  color: color,
                  selected: color == mine,
                  onTap: () async {
                    if (color == mine) return;
                    await ref.read(myColorProvider.notifier).set(color, ref.read(repositoryProvider));
                    if (context.mounted) showTwinsToast(context, '${color.label} it is. The icon changes once you leave the app');
                  },
                ),
            ],
          ),
          if (twin != null && twinColor != null) ...[
            const SizedBox(height: TwinsSpacing.md),
            Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: twinColor.accent, shape: BoxShape.circle)),
                const SizedBox(width: TwinsSpacing.xs),
                Expanded(
                  child: Text(
                    TwinColor.fromKey(twin.themeColor) == mine
                        ? '${twin.displayName} picked ${mine.label} too, so they show in ${twinColor.label} here'
                        : '${twin.displayName} is ${twinColor.label}',
                    style: TwinsTypography.body(palette.textSecondary, size: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final TwinColor color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: color.label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.accent,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? context.twins.textPrimary : Colors.transparent, width: 3),
              ),
              child: selected ? const Icon(PhosphorIconsBold.check, color: Colors.white, size: 20) : null,
            ),
            const SizedBox(height: 4),
            Text(color.label, style: TwinsTypography.label(context.twins.textSecondary, size: 11)),
          ],
        ),
      ),
    );
  }
}
