import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/urls.dart';
import '../services/external_link_service.dart';
import '../services/review_service.dart';
import 'offline_screen.dart';

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

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {
          setState(() {
            _progress = progress / 100;
          });
        },
        onNavigationRequest: (NavigationRequest request) {
          return ExternalLinkService.handleNavigation(request);
        },
      ))
      ..loadRequest(Uri.parse(AppUrls.home));

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      final offline = result.contains(ConnectivityResult.none);
      if (offline != _isOffline) {
        setState(() {
          _isOffline = offline;
        });
        if (!offline) {
          _controller.reload();
        }
      }
    });

    ReviewService.checkAndPrompt();
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
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
                  content: Text('Press back again to exit'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: _isOffline
              ? OfflineScreen(onRetry: _retryConnection)
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_progress < 1.0)
                      LinearProgressIndicator(value: _progress),
                  ],
                ),
        ),
      ),
    );
  }
}
