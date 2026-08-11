import 'package:flutter/material.dart';

/// The ¡Twins! folder silhouette: a chunky tabbed folder drawn as one flat
/// path, matching the brand sheet's folder cards.
///
/// Deliberately *not* a gradient two-tone "pocket" - the brand sheet folders
/// are a single flat fill with one continuous outline, which is what makes
/// them read as a sticker rather than a skeuomorphic file folder.
///
/// Content is positioned by [tabTopFactor] / [tabWidthFactor] so callers can
/// drop a glyph into the tab and text into the body without re-deriving the
/// geometry.
class FolderGlyph extends StatelessWidget {
  final Color color;

  /// Drawn inside the raised tab (the small "twins" mark on the brand sheet).
  final Widget? tab;

  /// Drawn inside the folder body.
  final Widget? child;

  /// Padding applied inside the body area, on top of the tab offset.
  final EdgeInsets bodyPadding;

  const FolderGlyph({
    super.key,
    required this.color,
    this.tab,
    this.child,
    this.bodyPadding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  /// Fraction of the height taken by the tab before the body starts.
  static const double tabTopFactor = 0.21;

  /// Fraction of the width spanned by the tab.
  static const double tabWidthFactor = 0.42;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final bodyTop = h * tabTopFactor;

        return CustomPaint(
          painter: _FolderPainter(color),
          child: Stack(
            children: [
              if (tab != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: w * tabWidthFactor,
                  height: bodyTop,
                  child: Center(child: tab),
                ),
              Positioned.fill(
                top: bodyTop,
                child: Padding(padding: bodyPadding, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FolderPainter extends CustomPainter {
  final Color color;
  _FolderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Chunky, sticker-like corners. Clamped so small cards don't collapse the
    // silhouette into a blob.
    final r = (w * 0.085).clamp(8.0, 20.0);
    final rt = r * 0.75; // tab corners are slightly tighter
    final bodyTop = h * FolderGlyph.tabTopFactor;
    final tabRight = w * FolderGlyph.tabWidthFactor;
    final notch = rt * 0.9; // fillet where the tab meets the body

    final path = Path()
      // Tab: top-left corner across to the top-right corner.
      ..moveTo(rt, 0)
      ..lineTo(tabRight - rt, 0)
      ..arcToPoint(Offset(tabRight, rt), radius: Radius.circular(rt))
      // Down the tab's right edge, easing into the body's top edge.
      ..lineTo(tabRight, bodyTop - notch)
      ..arcToPoint(
        Offset(tabRight + notch, bodyTop),
        radius: Radius.circular(notch),
        clockwise: false,
      )
      // Body top edge, right side, bottom, left side.
      ..lineTo(w - r, bodyTop)
      ..arcToPoint(Offset(w, bodyTop + r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, rt)
      ..arcToPoint(Offset(rt, 0), radius: Radius.circular(rt))
      ..close();

    // Soft grounded shadow, tinted by the folder colour so pastels don't go grey.
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = color.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FolderPainter old) => old.color != color;
}
