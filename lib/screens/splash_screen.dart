import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'webview_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _brandController;
  late final AnimationController _subtitleController;
  late final AnimationController _arabicController;

  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  late final Animation<double> _brandFade;
  late final Animation<double> _brandScale;

  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  late final Animation<double> _arabicFade;
  late final Animation<Offset> _arabicSlide;

  @override
  void initState() {
    super.initState();

    // Stage 1: Logo (0.0s - 1.5s)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    // Stage 2: Brand name "Digitronics.ma" (starts at 1.0s)
    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _brandFade = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeIn,
    );
    _brandScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _brandController,
        curve: Curves.easeOutBack,
      ),
    );

    // Stage 3: Subtitle (starts at 1.5s)
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _subtitleFade = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOut,
    ));

    // Stage 4: Arabic tagline (starts at 2.0s)
    _arabicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _arabicFade = CurvedAnimation(
      parent: _arabicController,
      curve: Curves.easeIn,
    );
    _arabicSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _arabicController,
      curve: Curves.easeOut,
    ));

    // Start staggered sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _brandController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _subtitleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _arabicController.forward();
    });

    // Navigate after all animations complete + pause
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WebViewScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _brandController.dispose();
    _subtitleController.dispose();
    _arabicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Back.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with slide-down + fade
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Image.asset(
                    'assets/logo.png',
                    width: MediaQuery.of(context).size.width * 0.45,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Brand name: "Digitronics.ma"
              ScaleTransition(
                scale: _brandScale,
                child: FadeTransition(
                  opacity: _brandFade,
                  child: Text(
                    'Digitronics.ma',
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        Shadow(
                          color: const Color(0xFFDD3333).withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle: "Best Electronics Store in Morocco"
              SlideTransition(
                position: _subtitleSlide,
                child: FadeTransition(
                  opacity: _subtitleFade,
                  child: Text(
                    'Best Electronics Store in Morocco',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Decorative divider line
              FadeTransition(
                opacity: _subtitleFade,
                child: Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Arabic tagline
              SlideTransition(
                position: _arabicSlide,
                child: FadeTransition(
                  opacity: _arabicFade,
                  child: Text(
                    'ديجيترونيك بعروضها ترضيك',
                    style: GoogleFonts.amiri(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDD3333),
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
