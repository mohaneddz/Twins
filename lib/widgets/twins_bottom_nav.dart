import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/colors.dart';
import '../theme/palette.dart';

class TwinsBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const TwinsBottomNav({super.key, required this.currentIndex, required this.onTap, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    // The nav bar stays deep navy in both themes: the brand sheet shows the
    // same bar under a light search screen and a dark dashboard, so it reads
    // as a fixed brand element rather than a surface that flips.
    final palette = context.twins;
    final bg = palette.navBar;
    final inactive = palette.navInactive;

    // Filled when active, outline when not - the weight change is what reads
    // as "selected" in the design, not colour alone.
    Widget navIcon(IconData filled, IconData outline, int index, String label) {
      final active = currentIndex == index;
      return IconButton(
        onPressed: () => onTap(index),
        tooltip: label,
        icon: Icon(active ? filled : outline, color: active ? TwinsColors.mikuGreen : inactive, size: 26),
      );
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            navIcon(PhosphorIconsFill.house, PhosphorIconsRegular.house, 0, 'Home'),
            navIcon(PhosphorIconsFill.folder, PhosphorIconsRegular.folder, 1, 'Folders'),
            Semantics(
              button: true,
              label: 'Add something',
              child: GestureDetector(
                onTap: onAddTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: TwinsColors.mikuGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x5900B3A4), blurRadius: 14, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
            navIcon(PhosphorIconsFill.chatCircle, PhosphorIconsRegular.chatCircle, 3, 'Chat'),
            navIcon(PhosphorIconsFill.usersThree, PhosphorIconsRegular.usersThree, 4, 'Our space'),
          ],
        ),
      ),
    );
  }
}
