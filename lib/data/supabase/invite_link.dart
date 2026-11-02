import 'dart:io';

import 'package:flutter/services.dart';

/// A twins://join link carrying a project's URL and publishable key - both
/// public values - so the second twin's phone connects without retyping them.
String buildInviteLink({required String url, required String publishableKey}) =>
    Uri(scheme: 'twins', host: 'join', queryParameters: {'u': url, 'k': publishableKey}).toString();

/// Finds an invite in whatever was pasted or opened (the bare link, or a
/// whole shared message containing it).
({String url, String publishableKey})? parseInvite(String text) {
  final match = RegExp(r'twins://join\?\S+').firstMatch(text);
  if (match == null) return null;
  final params = Uri.tryParse(match.group(0)!)?.queryParameters ?? const {};
  final url = params['u'];
  final key = params['k'];
  if (url == null || key == null || !url.startsWith('https://') || key.isEmpty) return null;
  return (url: url, publishableKey: key);
}

/// The invite link this launch came from, if the app was opened by tapping one.
Future<String?> takeLaunchInviteLink() async {
  if (!Platform.isAndroid) return null;
  try {
    return await const MethodChannel('twins/invite').invokeMethod<String>('takeLink');
  } on MissingPluginException {
    return null;
  }
}
