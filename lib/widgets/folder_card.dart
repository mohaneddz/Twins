import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/folder.dart';
import '../theme/palette.dart';
import '../theme/radius.dart';
import '../theme/typography.dart';
import 'folder_glyph.dart';

class FolderCard extends StatelessWidget {
  final TwinsFolder folder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FolderCard({super.key, required this.folder, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    // Folder colours are user-chosen pastels or brand green, so the label
    // colour has to be derived rather than fixed to either theme.
    final fg = onColor(folder.color);
    final muted = fg.withValues(alpha: 0.62);

    return Semantics(
      button: true,
      label: '${folder.name}, ${folder.itemCount} items',
      child: InkWell(
        borderRadius: TwinsRadius.lgRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: FolderGlyph(
          color: folder.color,
          tab: Text(folder.icon, style: const TextStyle(fontSize: 13)),
          bodyPadding: const EdgeInsets.fromLTRB(12, 8, 12, 11),
          // The pin overlays rather than sitting in the Column, so it never
          // competes with the label for the body's limited height.
          child: Stack(
            children: [
              if (folder.isPinned)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(PhosphorIconsFill.pushPin, size: 13, color: muted),
                ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwinsTypography.heading(fg, size: 14),
                    ),
                    Text(
                      '${folder.itemCount} ${folder.itemCount == 1 ? 'item' : 'items'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwinsTypography.label(muted, size: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add new" slot. Uses the same folder silhouette as an outline so it reads
/// as an empty folder in the grid rather than a different kind of tile.
class AddFolderCard extends StatelessWidget {
  final VoidCallback onTap;
  const AddFolderCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final accent = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Add a new folder',
      child: InkWell(
        borderRadius: TwinsRadius.lgRadius,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _DashedFolderPainter(palette.border),
              // Centre the affordance in the body area, below the tab.
              child: Padding(
                padding: EdgeInsets.only(top: constraints.maxHeight * FolderGlyph.tabTopFactor),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsBold.plus, color: accent, size: 22),
                    const SizedBox(height: 4),
                    Text('Add new', style: TwinsTypography.label(palette.textSecondary, size: 11)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The folder outline, stroked instead of filled, for the empty "add" slot.
class _DashedFolderPainter extends CustomPainter {
  final Color color;
  _DashedFolderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final r = (w * 0.085).clamp(8.0, 20.0);
    final rt = r * 0.75;
    final bodyTop = h * FolderGlyph.tabTopFactor;
    final tabRight = w * FolderGlyph.tabWidthFactor;
    final notch = rt * 0.9;

    final path = Path()
      ..moveTo(rt, 0)
      ..lineTo(tabRight - rt, 0)
      ..arcToPoint(Offset(tabRight, rt), radius: Radius.circular(rt))
      ..lineTo(tabRight, bodyTop - notch)
      ..arcToPoint(Offset(tabRight + notch, bodyTop), radius: Radius.circular(notch), clockwise: false)
      ..lineTo(w - r, bodyTop)
      ..arcToPoint(Offset(w, bodyTop + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, rt)
      ..arcToPoint(Offset(rt, 0), radius: Radius.circular(rt))
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_DashedFolderPainter old) => old.color != color;
}
