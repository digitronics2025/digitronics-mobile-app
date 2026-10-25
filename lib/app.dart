import 'package:flutter/material.dart';

import 'screens/webview_screen.dart';
import 'services/link_router.dart';

/// Digitronics brand red — used as the Material color seed so progress
/// indicators, snackbars and controls match the logo and splash.
const Color kBrandRed = Color(0xFFDD3333);

class DigitronicsApp extends StatefulWidget {
  const DigitronicsApp({super.key});

  @override
  State<DigitronicsApp> createState() => _DigitronicsAppState();
}

class _DigitronicsAppState extends State<DigitronicsApp> {
  // WebViewScreen owns the launch experience: it starts loading the site
  // immediately and shows the animated splash as an overlay, so the user
  // never waits through a splash and *then* a blank page load. The router
  // only turns App Links into PendingLink URLs for it.
  final LinkRouterDelegate _routerDelegate =
      LinkRouterDelegate(home: const WebViewScreen());
  final LinkRouteParser _routeParser = LinkRouteParser();

  @override
  void dispose() {
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Digitronics.ma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kBrandRed,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      themeMode: ThemeMode.light,
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeParser,
    );
  }
}
