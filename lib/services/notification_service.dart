import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_info.dart';
import '../constants/urls.dart';
import 'link_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification messages are rendered by the system tray automatically while
  // the app is backgrounded/terminated. Taps are handled via getInitialMessage
  // and onMessageOpenedApp, so no work is needed here.
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Backend endpoint that stores FCM tokens for targeted campaigns.
  static const String _registerEndpoint = AppUrls.pushRegisterEndpoint;

  static const Duration _httpTimeout = Duration(seconds: 10);

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'digitronics_channel',
    'Digitronics Notifications',
    description: 'Notifications from Digitronics',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _setupLocalNotifications();
    // Listeners first: the app is on screen while the permission prompt and
    // the token upload below run, and a message or tap in that window must
    // not be missed (a background-open tap is not replayed later).
    _listenForegroundMessages();
    _listenNotificationTaps();
    await _requestPermission();
    await _registerToken();
  }

  static Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Tapped notification: WebViewScreen opens the page (own site only).
        PendingLink.offer(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Subscribe to the broadcast topic, then register the device token with the
  /// backend so campaigns can target this device. Re-registers on refresh.
  static Future<void> _registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('all');
      final token = await messaging.getToken();
      if (token != null) {
        await _sendToken(token);
      }
      messaging.onTokenRefresh.listen(_sendToken);
    } catch (_) {
      // Non-fatal: notifications still display; only server targeting is lost.
    }
  }

  static Future<void> _sendToken(String token) async {
    final client = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse(_registerEndpoint))
          .timeout(_httpTimeout);
      request.headers.contentType = ContentType.json;
      // Identify app traffic in logs and to the WAF (see /push/register route).
      request.headers
          .set(HttpHeaders.userAgentHeader, appUserAgent('FCM-register'));
      request.add(utf8.encode(jsonEncode({
        'token': token,
        'platform': 'android',
        'appVersion': kAppVersion,
      })));
      // Every step is bounded: a stalled network must not hold a socket open.
      final response = await request.close().timeout(_httpTimeout);
      await response.drain<void>().timeout(_httpTimeout);
    } catch (_) {
      // Ignore network errors; the token is re-sent on next launch / refresh.
    } finally {
      client.close(force: true);
    }
  }

  static void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: _urlFrom(message),
      );
    });
  }

  /// Handle taps that bring the app to the foreground from a system-tray
  /// notification, both from a cold start and while backgrounded.
  static void _listenNotificationTaps() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _routeMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_routeMessage);
  }

  static void _routeMessage(RemoteMessage message) {
    PendingLink.offer(_urlFrom(message));
  }

  /// Extract a target URL from a message's data payload, if present.
  static String? _urlFrom(RemoteMessage message) {
    final data = message.data;
    final url = data['url'] ?? data['link'] ?? data['click_action'];
    if (url is String && url.isNotEmpty) return url;
    return null;
  }
}
