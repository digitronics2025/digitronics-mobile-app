import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/app_info.dart';
import '../constants/urls.dart';
import '../l10n/app_strings.dart';
import '../services/external_link_service.dart';
import '../services/link_router.dart';
import '../services/load_report_service.dart';
import '../services/navigation_tracker.dart';
import '../services/page_load_policy.dart';
import '../services/review_service.dart';
import 'retry_screen.dart';
import 'splash_screen.dart';

/// The app's single screen: the website in a WebView, plus the native states
/// around it (splash, loading, offline, load failed).
///
/// Since 1.0.13 a page that fails or never arrives can no longer leave a white
/// screen. A main-frame network error, a blank/blocked status or 20 s without
/// visible content counts as a failure; the first one per launch clears the
/// WebView HTTP cache and retries silently, the next shows [RetryScreen]. Every
/// failure is reported to the site ([LoadReportService]). See docs/GUIDE.md §11.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const String _lastLocaleKey = 'last_locale';
  static const String _cacheEpochKey = 'webview_cache_epoch';

  late final WebViewController _controller;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  SharedPreferences? _prefs;
  bool _started = false;

  String _locale = AppUrls.defaultLocale;
  AppStrings get _strings => AppStrings.of(_locale);

  double _progress = 0;
  bool _isOffline = false;
  bool _loadFailed = false;
  bool _pageEverShown = false;
  DateTime? _lastBackPress;

  // Splash overlay: dismissed once the first page has loaded AND a minimum
  // brand-display time has elapsed. After the hard fallback a loading screen
  // (never a white page) stays until content appears or the load fails.
  bool _showSplash = true;
  bool _minSplashElapsed = false;
  Timer? _minSplashTimer;
  Timer? _splashFallbackTimer;

  // Which navigation each WebView callback belongs to (see NavigationTracker:
  // Android's callback order varies, so this is kept out of the widget).
  final NavigationTracker _nav = NavigationTracker(
    AppUrls.homeFor(AppUrls.defaultLocale),
  );
  int _consecutiveFailures = 0;
  bool _autoRecoveryUsed = false;
  Timer? _loadWatchdog;
  Timer? _contentProbe;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
          onHttpError: _onHttpError,
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    PendingLink.url.addListener(_onPendingLink);

    _minSplashTimer = Timer(const Duration(milliseconds: 2500), () {
      _minSplashElapsed = true;
      _maybeHideSplash();
    });
    // Never let a slow/failed load trap the user behind the splash.
    _splashFallbackTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_showSplash) return;
      setState(() => _showSplash = false);
      if (!_pageEverShown) _startContentProbe();
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    unawaited(_start());
    ReviewService.checkAndPrompt();
  }

  @override
  void dispose() {
    _minSplashTimer?.cancel();
    _splashFallbackTimer?.cancel();
    _loadWatchdog?.cancel();
    _contentProbe?.cancel();
    PendingLink.url.removeListener(_onPendingLink);
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Preferences are an optimisation (locale, cache epoch), never required.
    }
    final deviceLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _locale = AppUrls.localeOrDefault(
      _prefs?.getString(_lastLocaleKey) ?? deviceLanguage,
    );

    // One-time cache clear after an update that needs it (kWebViewCacheEpoch).
    // clearCache() empties the HTTP cache only: cookies (the session) and
    // localStorage (the cart) are kept.
    if (_prefs?.getInt(_cacheEpochKey) != kWebViewCacheEpoch) {
      try {
        await _controller.clearCache();
        await _prefs?.setInt(_cacheEpochKey, kWebViewCacheEpoch);
      } catch (_) {
        // Retried on the next launch.
      }
    }

    final offline = await _connectivityIsNone();
    if (!mounted) return;
    // Only now does startup stop deferring links to itself: one tapped while
    // the checks above ran is taken here, never overwritten by the home page.
    _started = true;
    final firstPage = PendingLink.take() ?? AppUrls.homeFor(_locale);
    if (offline) {
      setState(() {
        _isOffline = true;
        _showSplash = false;
      });
      _nav.request(firstPage); // What _onConnectivityChanged will load.
      return; // _onConnectivityChanged loads the page once a network appears.
    }
    setState(() {});
    _load(firstPage);
  }

  Future<bool> _connectivityIsNone() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.none);
    } catch (_) {
      return false; // Unknown: try the network rather than block on a guess.
    }
  }

  void _load(String url) {
    _nav.request(url);
    _armWatchdog();
    _controller.loadRequest(Uri.parse(url));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final decision = ExternalLinkService.handleNavigation(request);
    // A link the page itself follows opens a navigation now, because Android
    // can report its error before it reports the page started.
    if (decision == NavigationDecision.navigate && request.isMainFrame) {
      _nav.request(request.url);
      _armWatchdog();
    }
    return decision;
  }

  void _armWatchdog() {
    _loadWatchdog?.cancel();
    _loadWatchdog = Timer(PageLoadPolicy.loadTimeout, _onLoadTimeout);
  }

  void _onPageStarted(String url) {
    _nav.started(url);
    _armWatchdog();
  }

  void _onPageFinished(String url) {
    if (!_nav.finishedSuccessfully(url)) return;
    unawaited(_confirmFinishedPage(url));
  }

  /// A nominal finish is not proof: an empty 200 or a page whose scripts died
  /// "finishes" too. Only visible content counts; otherwise the watchdog stays
  /// armed and treats the page as failed when it fires.
  Future<void> _confirmFinishedPage(String url) async {
    final generation = _nav.generation;
    final hasContent = await _pageHasContent();
    if (generation != _nav.generation || !mounted) return; // Superseded.
    if (!hasContent) {
      if (!(_loadWatchdog?.isActive ?? false)) _armWatchdog();
      if (!_pageEverShown) _startContentProbe();
      return;
    }
    _loadWatchdog?.cancel();
    _markPageShown();

    final locale = AppUrls.localeOf(Uri.parse(url));
    if (locale != null && locale != _locale) {
      _prefs?.setString(_lastLocaleKey, locale);
      if (mounted) setState(() => _locale = locale);
    }

    if (_consecutiveFailures > 0) {
      LoadReportService.report(
        message:
            'recovered after $_consecutiveFailures failure(s)${_autoRecoveryUsed ? ' and a cache clear' : ''}',
        url: PageLoadPolicy.stripQuery(url),
        locale: _locale,
      );
      _consecutiveFailures = 0;
    }
    unawaited(LoadReportService.flushPending());
  }

  void _markPageShown() {
    _contentProbe?.cancel();
    _pageEverShown = true;
    if (!mounted) return;
    // A page is on screen and usable (possibly from cache while offline), so
    // neither the retry nor the offline screen may keep covering it.
    setState(() {
      _loadFailed = false;
      _isOffline = false;
    });
    _maybeHideSplash();
  }

  void _onWebResourceError(WebResourceError error) {
    if (!PageLoadPolicy.isFatalResourceError(
      isForMainFrame: error.isForMainFrame,
      description: error.description,
    )) {
      return;
    }
    // A late error from the page being left must not fail the new one.
    final url = error.url;
    if (url != null && !_nav.isCurrentPage(url)) return;
    _fail(
      LoadFailure(
        LoadFailureKind.network,
        '${error.errorCode} ${error.errorType?.name ?? ''} ${error.description}'
            .trim(),
        error.url ?? _nav.target,
      ),
    );
  }

  void _onHttpError(HttpResponseError error) {
    final status = error.response?.statusCode;
    final url = error.request?.uri.toString();
    if (status == null || url == null) return;
    // Sub-resources report HTTP errors too; only the page itself counts.
    if (!_nav.isCurrentPage(url)) return;
    if (!PageLoadPolicy.isFatalHttpStatus(status)) return;
    _fail(LoadFailure(LoadFailureKind.http, 'status $status', url));
  }

  Future<void> _onLoadTimeout() async {
    final generation = _nav.generation;
    final hasContent = await _pageHasContent();
    // A navigation that opened while the check ran is not this one's to fail.
    if (generation != _nav.generation || !mounted) return;
    // A slow page that already shows something is left alone.
    if (hasContent) {
      _markPageShown();
      return;
    }
    _fail(
      LoadFailure(
        LoadFailureKind.timeout,
        'no content after ${PageLoadPolicy.loadTimeout.inSeconds}s (progress ${(_progress * 100).round()}%)',
        _nav.target,
      ),
    );
  }

  Future<bool> _pageHasContent() async {
    try {
      final result = await _controller
          .runJavaScriptReturningResult(PageLoadPolicy.contentCheckScript)
          .timeout(PageLoadPolicy.contentCheckTimeout);
      return PageLoadPolicy.hasContent(result);
    } catch (_) {
      return false; // A renderer that cannot answer shows nothing useful.
    }
  }

  /// While the loading screen covers the WebView, look for content every
  /// 1.5 s so a page that paints before its `load` event is shown at once.
  void _startContentProbe() {
    _contentProbe?.cancel();
    _contentProbe = Timer.periodic(const Duration(milliseconds: 1500), (
      _,
    ) async {
      if (_pageEverShown || _loadFailed) {
        _contentProbe?.cancel();
        return;
      }
      final generation = _nav.generation;
      final hasContent = await _pageHasContent();
      if (hasContent && generation == _nav.generation) _markPageShown();
    });
  }

  void _fail(LoadFailure failure) {
    if (!_nav.recordFailure()) return; // One failure per navigation.
    _loadWatchdog?.cancel();
    _contentProbe?.cancel();
    _consecutiveFailures++;

    LoadReportService.report(
      message:
          '${failure.describe()} attempt=$_consecutiveFailures${_autoRecoveryUsed ? ' after-cache-clear' : ''}',
      url: PageLoadPolicy.stripQuery(failure.url),
      locale: _locale,
    );

    if (!_autoRecoveryUsed) {
      // First failure this launch: a poisoned HTTP cache is the cheapest cause
      // to rule out, and clearing it is invisible to the shopper.
      _autoRecoveryUsed = true;
      unawaited(_clearCacheAndReload());
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadFailed = true;
      _showSplash = false;
    });
  }

  Future<void> _clearCacheAndReload() async {
    try {
      await _controller.clearCache();
    } catch (_) {
      // Reload anyway.
    }
    if (!mounted) return;
    _load(_nav.target); // The page that failed, not the one before it.
  }

  Future<void> _retry() async {
    if (await _connectivityIsNone()) {
      if (mounted) setState(() => _isOffline = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isOffline = false;
      _loadFailed = false;
      _progress = 0;
    });
    if (!_pageEverShown) _startContentProbe();
    await _clearCacheAndReload();
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final offline = result.contains(ConnectivityResult.none);
    if (offline == _isOffline || !mounted) return;
    setState(() => _isOffline = offline);
    // Back online: reload only what never loaded. A page already on screen
    // (a shopper mid-checkout) is left as it is.
    if (!offline && _started && (!_pageEverShown || _loadFailed)) {
      unawaited(_retry());
    }
  }

  void _onPendingLink() {
    if (!_started) return; // _start() takes it for the first page.
    final url = PendingLink.take();
    if (url == null) return;
    if (_isOffline) {
      _nav.request(url); // Loaded by _onConnectivityChanged when back online.
      return;
    }
    _load(url);
  }

  void _maybeHideSplash() {
    if (_pageEverShown && _minSplashElapsed && _showSplash && mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Back always tries the WebView history first, also from the retry or
        // offline screen: the previous page is usually still usable, and its
        // successful load clears the overlay (_markPageShown).
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.pressAgainToExit),
                duration: const Duration(seconds: 2),
              ),
            );
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
              child: Stack(
                children: [
                  // Always mounted, so a retry reuses the same WebView.
                  WebViewWidget(controller: _controller),
                  if (_progress < 1.0 && _pageEverShown)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(value: _progress),
                    ),
                  if (!_pageEverShown && !_loadFailed && !_isOffline)
                    Positioned.fill(
                      child: LoadingScreen(label: strings.loading),
                    ),
                  if (_loadFailed && !_isOffline)
                    Positioned.fill(
                      child: RetryScreen.loadFailed(strings, onRetry: _retry),
                    ),
                  if (_isOffline)
                    Positioned.fill(
                      child: RetryScreen.offline(strings, onRetry: _retry),
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
