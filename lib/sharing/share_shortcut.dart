import 'dart:io';

import 'package:flutter/services.dart';

/// Android-only: keeps a "share to this space" shortcut published so ¡Twins!
/// shows up in the system share sheet's top (Direct Share) row. Apps with
/// their own share panels (TikTok, Instagram) still list it under "More" -
/// those rows are curated by the apps themselves.
class ShareShortcut {
  static const _channel = MethodChannel('twins/shareShortcut');

  static Future<void> publish(String label) => _invoke('publish', {'label': label});

  static Future<void> remove() => _invoke('remove');

  static Future<void> _invoke(String method, [Object? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      // No native side under `flutter test`.
    }
  }
}
