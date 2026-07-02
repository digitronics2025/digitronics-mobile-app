import 'package:flutter/material.dart';
import 'screens/webview_screen.dart';

/// Digitronics brand red — used as the Material color seed so progress
/// indicators, snackbars and controls match the logo and splash.
const Color kBrandRed = Color(0xFFDD3333);

class DigitronicsApp extends StatelessWidget {
  const DigitronicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digitronics.ma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: kBrandRed,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      themeMode: ThemeMode.light,
      // WebViewScreen owns the launch experience: it starts loading the site
      // immediately and shows the animated splash as an overlay, so the user
      // never waits through a splash and *then* a blank page load.
      home: const WebViewScreen(),
    );
  }
}
