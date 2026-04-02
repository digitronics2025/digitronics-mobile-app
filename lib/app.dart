import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

class DigitronicsApp extends StatelessWidget {
  const DigitronicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digitronics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
