import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen brand splash shown as an overlay by [WebViewScreen] while the
/// site preloads underneath. It does not navigate — WebViewScreen removes it
/// once the first page is ready. Designed to sit seamlessly on top of the
/// brand-red native (OS) splash: same red, so the hand-off is invisible.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Brand palette (matches the native splash + app theme).
  static const Color _redTop = Color(0xFFE4232B);
  static const Color _redBottom = Color(0xFFB01A20);
  static const Color _cream = Color(0xFFFFE7D6);

  late final AnimationController _logo;
  late final AnimationController _brand;
  late final AnimationController _subtitle;
  late final AnimationController _arabic;
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();

    _logo = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _brand = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _subtitle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _arabic = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _loader = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _logo.forward();
    Future.delayed(const Duration(milliseconds: 450),
        () => mounted ? _brand.forward() : null);
    Future.delayed(const Duration(milliseconds: 750),
        () => mounted ? _subtitle.forward() : null);
    Future.delayed(const Duration(milliseconds: 1050),
        () => mounted ? _arabic.forward() : null);
    Future.delayed(const Duration(milliseconds: 1200),
        () => mounted ? _loader.forward() : null);
  }

  @override
  void dispose() {
    _logo.dispose();
    _brand.dispose();
    _subtitle.dispose();
    _arabic.dispose();
    _loader.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_redTop, _redBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft radial glow behind the logo to make it pop off the red.
            Align(
              alignment: const Alignment(0, -0.28),
              child: Container(
                width: size.width * 0.9,
                height: size.width * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Centered brand lockup.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo — fade + gentle scale/rise.
                  FadeTransition(
                    opacity: _fade(_logo),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1.0).animate(
                        CurvedAnimation(
                            parent: _logo, curve: Curves.easeOutBack),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        width: size.width * 0.42,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Wordmark.
                  FadeTransition(
                    opacity: _fade(_brand),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(parent: _brand, curve: Curves.easeOut),
                      ),
                      child: Text(
                        'Digitronics.ma',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle.
                  FadeTransition(
                    opacity: _fade(_subtitle),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_fade(_subtitle)),
                      child: Text(
                        'Best Electronics Store in Morocco',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Divider — animated width.
                  FadeTransition(
                    opacity: _fade(_subtitle),
                    child: Container(
                      width: 54,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Arabic tagline — now readable: warm cream on red.
                  FadeTransition(
                    opacity: _fade(_arabic),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(_fade(_arabic)),
                      child: Text(
                        'ديجيترونيك بعروضها ترضيك',
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.amiri(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: _cream,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subtle loading indicator near the bottom (the site is loading
            // behind this overlay).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: FadeTransition(
                    opacity: _fade(_loader),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
