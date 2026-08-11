import 'package:flutter/material.dart';
import '../data/models/item.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/formatters.dart';
import 'item_card.dart';

class ChatBubble extends StatelessWidget {
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final String? senderLabel;
  final TwinsItem? attachedItem;
  final int reactionCount;
  final VoidCallback? onTapAttachment;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.senderLabel,
    this.attachedItem,
    this.reactionCount = 0,
    this.onTapAttachment,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final bubbleColor = isMine ? TwinsColors.mikuMist : TwinsColors.folderPurple.withValues(alpha: 0.35);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
                child: Text(senderLabel!, style: TwinsTypography.label(TwinsColors.mikuGreen, size: 12)),
              ),
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.all(TwinsSpacing.sm),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: TwinsRadius.lgRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (attachedItem != null)
                    GestureDetector(
                      onTap: onTapAttachment,
                      child: SizedBox(
                        width: 160,
                        child: ItemCard(item: attachedItem!),
                      ),
                    ),
                  if (attachedItem != null && body.isNotEmpty) const SizedBox(height: 6),
                  if (body.isNotEmpty)
                    Text(body, style: TwinsTypography.body(TwinsColors.navy)),
                  const SizedBox(height: 4),
                  Text(formatClockTime(createdAt), style: TwinsTypography.label(TwinsColors.navy.withValues(alpha: 0.5), size: 10)),
                ],
              ),
            ),
            if (reactionCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: TwinsRadius.pillRadius,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
                  ),
                  child: Text('❤️ $reactionCount', style: TwinsTypography.label(palette.textSecondary, size: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
