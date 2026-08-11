import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const ScreenHeader({super.key, required this.title, this.actions, this.showBack = true, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.md, vertical: TwinsSpacing.xs),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(PhosphorIconsBold.caretLeft),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: Text(
                title,
                style: TwinsTypography.heading(Theme.of(context).colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}
