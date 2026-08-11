import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/typography.dart';

const quickReactions = ['❤️', '😭', '😂', '🔥', '👀', '💚'];

/// A compact reaction summary + tap-to-react control (used under items,
/// comments, and chat bubbles).
class ReactionBar extends StatelessWidget {
  final Map<String, int> counts;
  final bool myReactionActive;
  final VoidCallback onTapHeart;
  final VoidCallback onLongPressForPicker;

  const ReactionBar({
    super.key,
    required this.counts,
    required this.myReactionActive,
    required this.onTapHeart,
    required this.onLongPressForPicker,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return GestureDetector(
      onTap: onTapHeart,
      onLongPress: onLongPressForPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: myReactionActive ? TwinsColors.sakuraPink.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
          borderRadius: TwinsRadius.pillRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              myReactionActive ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
              size: 16,
              color: myReactionActive ? TwinsColors.sakuraPink : palette.textSecondary,
            ),
            if (total > 0) ...[
              const SizedBox(width: 6),
              Text('$total', style: TwinsTypography.label(palette.textSecondary, size: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> showReactionPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          alignment: WrapAlignment.center,
          children: quickReactions
              .map((e) => GestureDetector(
                    onTap: () => Navigator.of(context).pop(e),
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ))
              .toList(),
        ),
      ),
    ),
  );
}
