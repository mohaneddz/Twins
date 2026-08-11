import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/item.dart';
import '../data/models/item_type.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'media_thumbnail.dart';
import 'platform_badge.dart';

/// Grid card used in the dashboard "Recently added" strip and folder grids.
class ItemCard extends StatelessWidget {
  final TwinsItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  const ItemCard({super.key, required this.item, this.onTap, this.onLongPress, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final isNote = item.type == ItemType.note;

    return InkWell(
      borderRadius: TwinsRadius.lgRadius,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          // Chunky corners to match the brand sheet's sticker-like cards.
          borderRadius: TwinsRadius.lgRadius,
          color: palette.surface,
          border: selected ? Border.all(color: TwinsColors.mikuGreen, width: 2) : null,
          boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        // Shrink-wraps rather than using Expanded: the card is also rendered
        // in horizontally-scrolling strips where its height is unbounded, and
        // a non-zero flex under an unbounded constraint fails layout.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              // Wider than tall so the two-line title and the counts row still
              // fit inside a 0.78 grid cell (the ratio every caller uses)
              // without overflowing.
              aspectRatio: 1.3,
              child: isNote
                  ? _NoteCover(item: item)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaThumbnail(
                          url: item.thumbnailUrl,
                          fallbackIcon: PlatformBadge.visualFor(item.type).$1,
                          fallbackColor: PlatformBadge.visualFor(item.type).$2,
                        ),
                        Positioned(top: 8, left: 8, child: PlatformBadge(type: item.type, size: 24)),
                        if (item.durationMs != null)
                          Positioned(bottom: 8, right: 8, child: _DurationPill(ms: item.durationMs!)),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The brand sheet wraps card titles onto a second line
                  // rather than truncating them at the first word.
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TwinsTypography.heading(palette.textPrimary, size: 14),
                  ),
                  if (item.reactionCount > 0 || item.commentCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.reactionCount > 0) ...[
                          const Icon(PhosphorIconsFill.heart, size: 13, color: TwinsColors.sakuraPink),
                          const SizedBox(width: 3),
                          Text(
                            '${item.reactionCount}',
                            style: TwinsTypography.label(palette.textSecondary, size: 11),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.commentCount > 0) ...[
                          Icon(PhosphorIconsFill.chatCircle, size: 13, color: palette.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            '${item.commentCount}',
                            style: TwinsTypography.label(palette.textSecondary, size: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCover extends StatelessWidget {
  final TwinsItem item;
  const _NoteCover({required this.item});

  /// folderPeach blended onto white, kept as a literal so it is opaque.
  static const _paper = Color(0xFFFFECCA);

  @override
  Widget build(BuildContext context) {
    // Notes have no thumbnail, so the cover stands in for one: peach "paper"
    // with ruled lines, as the brand sheet draws them.
    //
    // Opaque rather than a translucent peach: alpha over the dark theme's
    // surface composites to a muddy brown instead of paper, and the point of
    // the cover is that it reads the same either way.
    return Container(
      color: _paper,
      padding: const EdgeInsets.all(TwinsSpacing.sm),
      child: Stack(
        children: [
          Positioned.fill(
            top: 34,
            child: CustomPaint(painter: _RuledLinesPainter(TwinsColors.navy.withValues(alpha: 0.14))),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(PhosphorIconsFill.notePencil, color: TwinsColors.danger, size: 22),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  item.content ?? '',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TwinsTypography.body(TwinsColors.navy.withValues(alpha: 0.75), size: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Evenly spaced ruled lines behind a note's preview text.
class _RuledLinesPainter extends CustomPainter {
  final Color color;
  _RuledLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 16.0;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RuledLinesPainter old) => old.color != color;
}

class _DurationPill extends StatelessWidget {
  final int ms;
  const _DurationPill({required this.ms});

  @override
  Widget build(BuildContext context) {
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$m:${s.toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
