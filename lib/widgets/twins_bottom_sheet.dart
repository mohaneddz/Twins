import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

Future<T?> showTwinsBottomSheet<T>({
  required BuildContext context,
  String? title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(TwinsSpacing.lg, TwinsSpacing.sm, TwinsSpacing.lg, TwinsSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: TwinsSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (title != null) ...[
                Text(title, style: TwinsTypography.heading(Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: TwinsSpacing.md),
              ],
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
