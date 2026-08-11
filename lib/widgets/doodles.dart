import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/colors.dart';

class _DoodleSpec {
  final double left;
  final double top;
  final double size;
  final IconData icon;
  final Color color;
  const _DoodleSpec(this.left, this.top, this.size, this.icon, this.color);
}

/// Small scattered outline doodles (stars, hearts, sparkles) used on the
/// welcome screen to match the playful scrapbook personality — original
/// shapes, not any copyrighted character artwork.
class DoodleField extends StatelessWidget {
  const DoodleField({super.key});

  static final _specs = <_DoodleSpec>[
    _DoodleSpec(24, 60, 34, PhosphorIconsBold.star, TwinsColors.mikuGreen),
    _DoodleSpec(280, 30, 16, PhosphorIconsBold.star, TwinsColors.sakuraPink),
    _DoodleSpec(300, 90, 24, PhosphorIconsBold.sparkle, TwinsColors.mikuGreen),
    _DoodleSpec(40, 260, 18, PhosphorIconsBold.plusCircle, TwinsColors.sakuraPink),
    _DoodleSpec(290, 250, 20, PhosphorIconsBold.tilde, TwinsColors.mikuGreen),
    _DoodleSpec(30, 330, 26, PhosphorIconsBold.heartStraight, TwinsColors.mikuGreen),
    _DoodleSpec(270, 340, 24, PhosphorIconsFill.heart, TwinsColors.sakuraPink),
    _DoodleSpec(20, 500, 18, PhosphorIconsBold.tilde, TwinsColors.mikuGreen),
    _DoodleSpec(300, 500, 20, PhosphorIconsBold.scribbleLoop, TwinsColors.mikuGreen),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _specs
          .map((s) => Positioned(
                left: s.left,
                top: s.top,
                child: Icon(s.icon, size: s.size, color: s.color.withValues(alpha: 0.55)),
              ))
          .toList(),
    );
  }
}
