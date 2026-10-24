import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The shop starts loading at once. Notifications used to be set up first —
  // a permission prompt, an FCM token fetch and a token upload — which could
  // hold a slow phone on the launch screen before the page even began.
  runApp(const DigitronicsApp());
  unawaited(_initNotifications());
}

Future<void> _initNotifications() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (_) {
    // Firebase not configured yet — app still works without notifications
  }
}
