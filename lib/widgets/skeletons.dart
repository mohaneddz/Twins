import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/palette.dart';
import '../theme/radius.dart';

class TwinsSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;

  const TwinsSkeletonBox({super.key, this.width, this.height = 16, this.radius});

  @override
  Widget build(BuildContext context) {
    final palette = context.twins;
    return Shimmer.fromColors(
      baseColor: palette.surfaceMuted,
      highlightColor: palette.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? TwinsRadius.smRadius,
        ),
      ),
    );
  }
}

class FolderGridSkeleton extends StatelessWidget {
  const FolderGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, __) => TwinsSkeletonBox(radius: TwinsRadius.lgRadius, height: double.infinity),
    );
  }
}
