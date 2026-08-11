import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/colors.dart';

/// Native playback for uploaded/direct video via video_player + chewie,
/// wired so external timestamp comments can seek it. Accepts either a
/// network/signed URL or a local on-device file path (mock mode stores
/// plain local paths rather than URLs).
class VideoPlayerView extends StatefulWidget {
  final String url;
  final ValueChanged<VideoPlayerController>? onControllerReady;

  const VideoPlayerView({super.key, required this.url, this.onControllerReady});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late final VideoPlayerController _controller;
  ChewieController? _chewie;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final isNetwork = widget.url.startsWith('http://') || widget.url.startsWith('https://');
    _controller = isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
        : VideoPlayerController.file(File(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _chewie = ChewieController(
          videoPlayerController: _controller,
          autoPlay: false,
          looping: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: TwinsColors.mikuGreen,
            handleColor: TwinsColors.mikuGreen,
            bufferedColor: TwinsColors.mikuLight.withValues(alpha: 0.4),
          ),
        );
      });
      widget.onControllerReady?.call(_controller);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Icon(Icons.error_outline, color: Colors.white54, size: 40)),
      );
    }
    if (!_ready || _chewie == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: TwinsColors.mikuGreen)),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
      child: Chewie(controller: _chewie!),
    );
  }
}
