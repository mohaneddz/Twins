import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/item_type.dart';
import '../theme/colors.dart';

class PlatformBadge extends StatelessWidget {
  final ItemType type;
  final double size;

  const PlatformBadge({super.key, required this.type, this.size = 26});

  /// The (icon, brand colour) pair for an item type. Shared with
  /// [MediaThumbnail] so a thumbnail-less/failed card falls back to the same
  /// branded glyph instead of a generic broken-image icon.
  static (IconData, Color) visualFor(ItemType type) => switch (type) {
        ItemType.tiktok => (PhosphorIconsFill.musicNote, const Color(0xFF010101)),
        ItemType.reel || ItemType.short => (PhosphorIconsFill.instagramLogo, TwinsColors.sakuraPink),
        ItemType.youtube => (PhosphorIconsFill.youtubeLogo, const Color(0xFFFF0000)),
        ItemType.video => (PhosphorIconsFill.playCircle, TwinsColors.vibrantBlue),
        ItemType.image => (PhosphorIconsFill.image, TwinsColors.mikuGreen),
        ItemType.gif => (PhosphorIconsFill.filmStrip, TwinsColors.sakuraPink),
        ItemType.note => (PhosphorIconsFill.notePencil, TwinsColors.warning),
        ItemType.document => (PhosphorIconsFill.fileText, TwinsColors.vibrantBlue),
        ItemType.audio => (PhosphorIconsFill.microphone, TwinsColors.mikuGreen),
        ItemType.link => (PhosphorIconsFill.linkSimple, TwinsColors.skyBlue),
        ItemType.other => (PhosphorIconsFill.folder, TwinsColors.lightTextSecondary),
      };

  (IconData, Color) get _visual => visualFor(type);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TwinsColors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.6, color: color),
    );
  }
}
