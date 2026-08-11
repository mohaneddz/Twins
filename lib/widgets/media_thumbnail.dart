import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/palette.dart';
import '../theme/colors.dart';

/// Renders either a remote image (network/signed URL) or a local on-device
/// file path. Mock mode (and any not-yet-uploaded preview) stores plain
/// local file paths rather than URLs, so this must handle both.
class MediaThumbnail extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Branded fallback shown when there's no image or it fails to load. Callers
  /// (e.g. item cards) pass the item type's glyph/colour so a link/video with
  /// no thumbnail reads as that platform instead of a generic broken image.
  final IconData? fallbackIcon;
  final Color? fallbackColor;

  const MediaThumbnail({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon,
    this.fallbackColor,
  });

  bool get _isNetwork => url != null && (url!.startsWith('http://') || url!.startsWith('https://'));

  Widget _fallback(BuildContext context) {
    final palette = context.twins;
    final color = fallbackColor ?? TwinsColors.mikuGreen;
    final icon = fallbackIcon ?? Icons.image_outlined;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.16), palette.surfaceMuted],
        ),
      ),
      child: Center(child: Icon(icon, color: color.withValues(alpha: 0.75), size: 34)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    final radius = borderRadius ?? BorderRadius.zero;
    if (url == null || url!.isEmpty) {
      return ClipRRect(borderRadius: radius, child: _fallback(context));
    }

    if (!_isNetwork) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(url!),
          fit: fit,
          errorBuilder: (context, _, __) => _fallback(context),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: palette.surfaceMuted,
          highlightColor: palette.border,
          child: Container(color: Colors.white),
        ),
        errorWidget: (context, _, __) => _fallback(context),
      ),
    );
  }
}
