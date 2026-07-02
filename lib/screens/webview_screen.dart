import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/urls.dart';
import '../services/external_link_service.dart';
import '../services/notification_service.dart';
import '../services/review_service.dart';
import 'offline_screen.dart';
import 'splash_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _isOffline = false;
  DateTime? _lastBackPress;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // Splash overlay: dismissed once the first page has loaded AND a minimum
  // brand-display time has elapsed, with a hard fallback so it never sticks.
  bool _showSplash = true;
  bool _pageLoaded = false;
  bool _minSplashElapsed = false;
  Timer? _minSplashTimer;
  Timer? _splashFallbackTimer;

  @override
  void initState() {
    super.initState();

    // If the app was launched from a notification, honor its URL immediately.
    final launchUrl = NotificationService.pendingUrl.value;
    final initialUrl =
        (launchUrl != null && launchUrl.isNotEmpty) ? launchUrl : AppUrls.home;
    NotificationService.pendingUrl.value = null;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress / 100;
          });
        },
        onPageFinished: (_) {
          _pageLoaded = true;
          _maybeHideSplash();
        },
        onNavigationRequest: (NavigationRequest request) {
          return ExternalLinkService.handleNavigation(request);
        },
      ))
      ..loadRequest(Uri.parse(initialUrl));

    NotificationService.pendingUrl.addListener(_onPendingUrl);

    _minSplashTimer = Timer(const Duration(milliseconds: 2500), () {
      _minSplashElapsed = true;
      _maybeHideSplash();
    });
    // Never let a slow/failed load trap the user behind the splash.
    _splashFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _showSplash) setState(() => _showSplash = false);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        final offline = result.contains(ConnectivityResult.none);
        if (offline != _isOffline) {
          setState(() {
            _isOffline = offline;
          });
          if (!offline) {
            _controller.reload();
          }
        }
      },
    );

    ReviewService.checkAndPrompt();
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _splashFallbackTimer?.cancel();
    NotificationService.pendingUrl.removeListener(_onPendingUrl);
    _connectivitySub.cancel();
    super.dispose();
  }

  void _onPendingUrl() {
    final url = NotificationService.pendingUrl.value;
    if (url == null || url.isEmpty) return;
    NotificationService.pendingUrl.value = null; // consume
    _controller.loadRequest(Uri.parse(url));
  }

  void _maybeHideSplash() {
    if (_pageLoaded && _minSplashElapsed && _showSplash && mounted) {
      setState(() => _showSplash = false);
    }
  }

  Future<void> _retryConnection() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result.contains(ConnectivityResult.none);
    setState(() {
      _isOffline = offline;
    });
    if (!offline) {
      _controller.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          final now = DateTime.now();
          if (_lastBackPress != null &&
              now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
            SystemNavigator.pop();
          } else {
            _lastBackPress = now;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appuyez à nouveau pour quitter'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              // Let the site run to the bottom edge — the website handles its
              // own bottom inset, so a bottom safe-area here just adds a white
              // gap below the site's nav bar.
              bottom: false,
              child: _isOffline
                  ? OfflineScreen(onRetry: _retryConnection)
                  : Stack(
                      children: [
                        WebViewWidget(controller: _controller),
                        if (_progress < 1.0)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(value: _progress),
                          ),
                      ],
                    ),
            ),
            if (_showSplash) const Positioned.fill(child: SplashScreen()),
          ],
        ),
      ),
    );
  }
}
