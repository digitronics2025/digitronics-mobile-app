import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_info.dart';

/// What the shop page may know about the app it runs in (SHOP_CHAT_APP_PLAN
/// Phase 3/4). Injected only into digitronics.ma pages after they load.
///
/// The website chat reads `window.__digitronicsApp` to (1) show "Open
/// DigiTronics" instead of an install invitation, and (2) when the customer
/// turns on reply notifications, bind THIS device's FCM token to their own chat
/// session (server-verified from the WebView's chat cookie). The token alone
/// grants nothing: the server pushes only devices bound to sessions the inbox
/// names for a reply. Nothing here subscribes to a topic.
class AppBridge {
  /// The latest FCM token, kept current by NotificationService.
  static final ValueNotifier<String?> fcmToken = ValueNotifier<String?>(null);

  /// The JavaScript that publishes the bridge, with every value JSON-encoded so
  /// no token or version can break out of the literal.
  static String script({required String version, String? token}) {
    final payload = jsonEncode({
      'platform': 'android',
      'version': version,
      if (token != null && token.isNotEmpty) 'fcmToken': token,
    });
    return 'window.__digitronicsApp=Object.freeze($payload);'
        "window.dispatchEvent(new Event('digitronics:app-bridge'));";
  }

  static String current() =>
      script(version: kAppVersion, token: fcmToken.value);
}
