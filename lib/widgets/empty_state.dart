import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({super.key, required this.emoji, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final secondary = palette.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TwinsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: TwinsSpacing.md),
            Text(title, textAlign: TextAlign.center, style: TwinsTypography.heading(
                palette.textPrimary, size: 18)),
            if (subtitle != null) ...[
              const SizedBox(height: TwinsSpacing.xs),
              Text(subtitle!, textAlign: TextAlign.center, style: TwinsTypography.body(secondary)),
            ],
            if (action != null) ...[const SizedBox(height: TwinsSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
