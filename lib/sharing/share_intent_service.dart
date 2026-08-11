import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pendingShareKey = 'twins_pending_shared_text';

/// Listens for content shared into the app from other apps' OS share sheets
/// (TikTok/Instagram/YouTube/Browser -> Share -> ¡Twins!) and exposes it as
/// a single stream of plain text/URLs ready to hand to the Add Item flow.
///
/// If the user isn't logged in yet when a share arrives, the payload is
/// cached to disk via [stashPendingShare] and replayed after login by
/// calling [consumePendingShare] once the app reaches the home shell.
class ShareIntentService {
  ShareIntentService._();
  static final instance = ShareIntentService._();

  final _controller = StreamController<String>.broadcast();
  StreamSubscription? _mediaSub;
  bool _started = false;

  /// Emits shared text/urls as they arrive while the app is already running.
  Stream<String> get sharedTextStream => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      final text = _extractText(initial);
      if (text != null) _controller.add(text);
    } catch (_) {
      // No initial share (or platform channel unavailable, e.g. in tests).
    }

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      final text = _extractText(files);
      if (text != null) _controller.add(text);
      ReceiveSharingIntent.instance.reset();
    }, onError: (_) {});
  }

  String? _extractText(List<SharedMediaFile> files) {
    if (files.isEmpty) return null;
    final file = files.first;
    switch (file.type) {
      case SharedMediaType.url:
      case SharedMediaType.text:
        return file.path;
      case SharedMediaType.image:
      case SharedMediaType.video:
      case SharedMediaType.file:
        // Non-text shares (a raw image/video/file) aren't wired into the
        // upload flow from the OS share sheet yet - only link/text shares
        // are. The local "From device" picker in Add Item covers uploads.
        return null;
    }
  }

  Future<void> stashPendingShare(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingShareKey, text);
  }

  Future<String?> consumePendingShare() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingShareKey);
    if (value != null) await prefs.remove(_pendingShareKey);
    return value;
  }

  void dispose() {
    _mediaSub?.cancel();
  }
}
