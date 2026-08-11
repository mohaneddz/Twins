import 'package:flutter/material.dart';
import '../data/models/comment.dart';
import '../data/models/profile.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/formatters.dart';
import 'avatars.dart';

class CommentBubble extends StatelessWidget {
  final TwinsComment comment;
  final Profile author;
  final ValueChanged<int>? onTapTimestamp;

  const CommentBubble({super.key, required this.comment, required this.author, this.onTapTimestamp});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final secondary = palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(profile: author, size: 32),
          const SizedBox(width: TwinsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(author.displayName, style: TwinsTypography.label(palette.textPrimary)),
                    const SizedBox(width: 8),
                    if (comment.mediaTimestampMs != null)
                      GestureDetector(
                        onTap: () => onTapTimestamp?.call(comment.mediaTimestampMs!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: TwinsColors.mikuGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formatTimestamp(comment.mediaTimestampMs!),
                            style: TwinsTypography.label(TwinsColors.mikuGreen, size: 11),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(formatRelativeTime(comment.createdAt), style: TwinsTypography.label(secondary, size: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: TwinsTypography.body(palette.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String? timestampLabel;
  final VoidCallback? onClearTimestamp;

  const CommentComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.timestampLabel,
    this.onClearTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timestampLabel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Chip(
                label: Text('at $timestampLabel'),
                onDeleted: onClearTimestamp,
                backgroundColor: TwinsColors.mikuGreen.withValues(alpha: 0.15),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Add a comment...'),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: TwinsSpacing.sm),
            CircleAvatar(
              backgroundColor: TwinsColors.mikuGreen,
              child: IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
