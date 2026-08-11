import 'package:flutter/material.dart';
import '../../theme/palette.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = <(String, String)>[
    (
      'How do I save something from another app?',
      'Open the share sheet in TikTok, Instagram, YouTube, or your browser and tap "¡Twins!". It opens Add Item with the link already filled in.',
    ),
    (
      'Can more than two people join our space?',
      "No - a Twins space is capped at exactly two members, enforced on the server. A third person trying to join with your code will be rejected.",
    ),
    (
      'What happens if I delete a folder?',
      'Everything inside it (items, subfolders, comments) is deleted too. This can\'t be undone, so you\'ll always be asked to confirm first.',
    ),
    (
      'Why can\'t I play a TikTok/Reel inside the app?',
      "Platform terms don't allow re-hosting that video. You'll see the thumbnail, title, and an \"Open original\" button instead.",
    ),
    (
      'Does this work without internet?',
      'Recently loaded folders/items stay visible, but adding, commenting, and reacting need a connection to sync with your twin.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help center')),
      body: ListView.separated(
        padding: const EdgeInsets.all(TwinsSpacing.lg),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: TwinsSpacing.sm),
        itemBuilder: (context, index) {
          final (question, answer) = _faqs[index];
          return Container(
            padding: const EdgeInsets.all(TwinsSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: TwinsRadius.lgRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: TwinsTypography.heading(Theme.of(context).colorScheme.onSurface, size: 15)),
                const SizedBox(height: 6),
                Text(answer, style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
              ],
            ),
          );
        },
      ),
    );
  }
}
