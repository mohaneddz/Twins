import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/profile.dart';
import '../state/twin_color_provider.dart';
import '../theme/colors.dart';

/// A twin's photo, or their initial on a gradient of their colour.
class UserAvatar extends ConsumerWidget {
  final Profile profile;
  final double size;
  final Color? ringColor;

  const UserAvatar({super.key, required this.profile, this.size = 40, this.ringColor});

  ImageProvider? get _avatarImage {
    final url = profile.avatarUrl;
    if (url == null || url.isEmpty) return null;
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    return isNetwork ? NetworkImage(url) : FileImage(File(url));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(colorOfUserProvider(profile.id));
    final initials = profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?';
    final avatarImage = _avatarImage;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
        gradient: LinearGradient(
          colors: [color.accent, color.light],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: avatarImage != null ? DecorationImage(image: avatarImage, fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: avatarImage == null
          ? Text(
              initials,
              style: TextStyle(
                color: TwinsColors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.4,
              ),
            )
          : null,
    );
  }
}

/// Overlapping pair of avatars for the joint Twins profile header.
class TwinAvatars extends StatelessWidget {
  final Profile a;
  final Profile b;
  final double size;

  const TwinAvatars({super.key, required this.a, required this.b, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size,
      child: Stack(
        children: [
          Positioned(left: 0, child: UserAvatar(profile: a, size: size, ringColor: TwinsColors.white)),
          Positioned(
            left: size * 0.6,
            child: UserAvatar(profile: b, size: size, ringColor: TwinsColors.white),
          ),
        ],
      ),
    );
  }
}
