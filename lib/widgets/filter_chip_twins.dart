import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/typography.dart';

class TwinsFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TwinsFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? TwinsColors.mikuGreen
              : (palette.chipBg),
          borderRadius: TwinsRadius.pillRadius,
        ),
        child: Text(
          label,
          style: TwinsTypography.label(
            selected ? TwinsColors.white : (palette.chipText),
          ),
        ),
      ),
    );
  }
}
