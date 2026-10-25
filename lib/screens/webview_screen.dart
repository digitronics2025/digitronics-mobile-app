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

  /// The navigation whose content was accepted ([_acceptPage]). Its late
  /// partial progress is ignored, so a page that shows content but never
  /// finishes does not keep a frozen bar.
  int? _shownGeneration;
  bool _isOffline = false;
  bool _loadFailed = false;
  bool _pageEverShown = false;

  /// The committed document of the current navigation is blank (an empty 200,
  /// a page whose scripts died): covered by the loading screen until content
  /// appears or the load fails, on any navigation.
  bool _coverBlankPage = false;

  /// While offline, a page loaded from cache is usable, so the offline screen
  /// steps aside without pretending the network is back.
  bool _cachedPageWhileOffline = false;

  bool get _needsContentCover => !_pageEverShown || _coverBlankPage;
  bool get _showOffline => _isOffline && !_cachedPageWhileOffline;
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

  /// A page asked for while offline (the first page, or a tapped link): the
  /// next reconnect or Retry opens it instead of dropping it.
  String? _queuedLink;

  /// The latest connectivity event received before startup finished, if any.
  bool? _startupConnectivityOffline;

  /// Counts connectivity events, so an async snapshot can tell that a newer
  /// event arrived while it was taken (see _retry).
  int _connectivityEventCount = 0;
  bool _autoRecoveryUsed = false;
  Timer? _loadWatchdog;
  Timer? _blankCheck;
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
            if (!mounted || _nav.generation == _shownGeneration) return;
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
    _blankCheck?.cancel();
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

    final snapshotOffline = await _connectivityIsNone();
    if (!mounted) return;
    // A connectivity event delivered while startup ran is newer than (or as
    // new as) the snapshot taken above, and its transition is not repeated.
    final offline = _startupConnectivityOffline ?? snapshotOffline;
    // Only now does startup stop deferring links to itself: one tapped while
    // the checks above ran is taken here, never overwritten by the home page.
    _started = true;
    final link = PendingLink.take();
    final firstPage = link != null
        ? _resolveLink(link)
        : AppUrls.homeFor(_locale);
    if (offline) {
      setState(() {
        _isOffline = true;
        _showSplash = false;
      });
      _queuedLink = firstPage; // Loaded once a network appears.
      return;
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
    // A stale start (a replaced request) must not extend the current load's
    // deadline.
    if (!_nav.started(url)) return;
    _armWatchdog();
    if (_needsContentCover || _loadFailed) {
      // Something covers the WebView (the first load, a blank page, a failure
      // screen): show this page as soon as it paints, finish or not.
      _startContentProbe();
    } else if (_pageEverShown) {
      _scheduleBlankCheck();
    }
  }

  /// A later page that commits blank and then hangs before its finish would
  /// leave the WebView white until the watchdog. One check a few seconds after
  /// the start covers it with the loading screen instead; a page that shows
  /// content by then is untouched (no spinner flash on normal navigations).
  void _scheduleBlankCheck() {
    _blankCheck?.cancel();
    final generation = _nav.generation;
    _blankCheck = Timer(PageLoadPolicy.blankCheckDelay, () async {
      if (!_stillPending(generation) || _loadFailed) return;
      final contentUrl = await _visibleContentUrl();
      if (contentUrl != null || !_stillPending(generation)) return;
      setState(() => _coverBlankPage = true);
      _startContentProbe();
    });
  }

  void _onPageFinished(String url) {
    if (!_nav.finishedSuccessfully(url)) return;
    unawaited(_confirmFinishedPage());
  }

  /// A nominal finish is not proof: an empty 200 or a page whose scripts died
  /// "finishes" too. Only visible content counts; otherwise the watchdog stays
  /// armed and treats the page as failed when it fires.
  Future<void> _confirmFinishedPage() async {
    final generation = _nav.generation;
    final contentUrl = await _visibleContentUrl();
    if (!_stillPending(generation)) return;
    if (contentUrl == null) {
      if (!(_loadWatchdog?.isActive ?? false)) _armWatchdog();
      // The committed document is blank: cover it (on any navigation, not
      // only the first) until content appears or the load fails.
      setState(() => _coverBlankPage = true);
      _startContentProbe();
      return;
    }
    _acceptPage(contentUrl);
  }

  /// Whether a check started for navigation [generation] may still act: the
  /// navigation is current and its content has not been accepted yet. Every
  /// check awaits the WebView, so each re-asks this after the await — a check
  /// in flight when the page was accepted (or replaced) drops its result.
  bool _stillPending(int generation) =>
      mounted &&
      generation == _nav.generation &&
      _shownGeneration != generation;

  /// The one place a page is accepted as shown, whichever check saw it first
  /// (the finish, the content probe, or the load deadline). [url] is the page
  /// the content check saw.
  void _acceptPage(String url) {
    _loadWatchdog?.cancel();
    _blankCheck?.cancel();
    _contentProbe?.cancel();
    _pageEverShown = true;
    _shownGeneration = _nav.generation;
    final locale = AppUrls.localeOf(Uri.parse(url));
    if (locale != null && locale != _locale) {
      _prefs?.setString(_lastLocaleKey, locale);
    }
    // A page is on screen and usable (possibly from cache while offline), so
    // neither the retry nor the offline screen may keep covering it. The
    // connectivity state itself is left alone: links tapped meanwhile still
    // queue, and the real reconnect still fires.
    setState(() {
      if (locale != null) _locale = locale;
      _loadFailed = false;
      _coverBlankPage = false;
      _progress = 1.0;
      if (_isOffline) _cachedPageWhileOffline = true;
    });
    _maybeHideSplash();

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

  void _onWebResourceError(WebResourceError error) {
    if (!PageLoadPolicy.isFatalResourceError(
      isForMainFrame: error.isForMainFrame,
      description: error.description,
    )) {
      return;
    }
    // A late error from the page being left must not fail the new one, and
    // one arriving after the page's content was accepted (a reset once the
    // body painted) must not cover a usable page.
    if (_nav.generation == _shownGeneration) return;
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
    // Sub-resources report HTTP errors too; only the page itself counts, and
    // only while its content has not been accepted.
    if (_nav.generation == _shownGeneration) return;
    if (!_nav.isCurrentPage(url)) return;
    if (!PageLoadPolicy.isFatalHttpStatus(status)) return;
    _fail(LoadFailure(LoadFailureKind.http, 'status $status', url));
  }

  Future<void> _onLoadTimeout() async {
    final generation = _nav.generation;
    final contentUrl = await _visibleContentUrl();
    // A navigation that opened, or content accepted, while the check ran is
    // not this check's to fail.
    if (!_stillPending(generation)) return;
    // A slow page that already shows something is left alone.
    if (contentUrl != null) {
      _acceptPage(contentUrl);
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

  /// The URL of the page on screen when it shows content of the navigation
  /// being tracked, else null. While the requested page has not started, the
  /// WebView may still show the previous page; its text only counts if it IS
  /// the requested page.
  Future<String?> _visibleContentUrl() async {
    try {
      final result = await _controller
          .runJavaScriptReturningResult(PageLoadPolicy.contentCheckScript)
          .timeout(PageLoadPolicy.contentCheckTimeout);
      final url = PageLoadPolicy.contentPageUrl(result);
      if (url == null) return null;
      return (!_nav.awaitingStart || _nav.isCurrentPage(url)) ? url : null;
    } catch (_) {
      return null; // A renderer that cannot answer shows nothing useful.
    }
  }

  /// While the loading screen covers the WebView, look for content every
  /// 1.5 s so a page that paints before its `load` event is shown at once.
  void _startContentProbe() {
    _contentProbe?.cancel();
    _contentProbe = Timer.periodic(const Duration(milliseconds: 1500), (
      _,
    ) async {
      // Nothing left to uncover, or the page being loaded already failed (a
      // newer navigation, e.g. Back from the failure screen, is probed again).
      if (!(_needsContentCover || _loadFailed) || _nav.currentFailed) {
        _contentProbe?.cancel();
        return;
      }
      final generation = _nav.generation;
      final contentUrl = await _visibleContentUrl();
      if (contentUrl != null && _stillPending(generation)) {
        _acceptPage(contentUrl);
      }
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

  /// [generation] is the navigation the recovery was started for (Retry
  /// captures it before its own await); a newer one cancels the reload.
  Future<void> _clearCacheAndReload([int? generation]) async {
    generation ??= _nav.generation;
    // The failed page (blank, or WebView's own error page) stays covered by
    // the loading screen through the cache clear and the reload, until the
    // reloaded page shows content (_acceptPage) or fails again.
    if (mounted) setState(() => _coverBlankPage = true);
    try {
      await _controller.clearCache();
    } catch (_) {
      // Reload anyway.
    }
    if (!mounted) return;
    // A newer navigation (Back, a link once online) opened meanwhile: it owns
    // the screen now, and reloading would interrupt it. The cover stays until
    // that page shows content, which the probe watches for even if it never
    // reports a finish.
    if (generation != _nav.generation) {
      if (_coverBlankPage) _startContentProbe();
      return;
    }
    // A link queued while offline wins; otherwise the page that failed, not
    // the one before it.
    final queued = _queuedLink;
    _queuedLink = null;
    _load(queued ?? _nav.target);
  }

  Future<void> _retry() async {
    final generation = _nav.generation;
    final eventsBefore = _connectivityEventCount;
    final snapshotOffline = await _connectivityIsNone();
    // An event delivered while the snapshot was taken is at least as new and
    // has already updated _isOffline; its transition will not come again.
    final offline = eventsBefore != _connectivityEventCount
        ? _isOffline
        : snapshotOffline;
    if (offline) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _cachedPageWhileOffline = false;
        });
      }
      return;
    }
    // Back (or a link) during the snapshot opened a newer navigation: Retry
    // must not reload the failed page over it.
    if (!mounted || generation != _nav.generation) return;
    setState(() {
      _isOffline = false;
      _loadFailed = false;
      _progress = 0;
    });
    if (!_pageEverShown) _startContentProbe();
    await _clearCacheAndReload(generation);
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    _connectivityEventCount++;
    final offline = result.contains(ConnectivityResult.none);
    if (!_started) {
      _startupConnectivityOffline = offline; // _start() applies the latest.
      return;
    }
    if (offline == _isOffline || !mounted) return;
    setState(() {
      _isOffline = offline;
      _cachedPageWhileOffline = false;
    });
    if (offline) return;
    // Back online: open a link tapped while offline, else reload only what
    // never loaded. A page already on screen (a shopper mid-checkout) is left
    // as it is.
    final queued = _queuedLink;
    if (queued != null && _pageEverShown && !_loadFailed) {
      _queuedLink = null;
      _load(queued);
    } else if (queued != null || !_pageEverShown || _loadFailed) {
      unawaited(_retry());
    }
  }

  void _onPendingLink() {
    if (!_started) return; // _start() takes it for the first page.
    final link = PendingLink.take();
    if (link == null) return;
    final url = _resolveLink(link);
    if (_isOffline) {
      _queuedLink = url; // Opened by _onConnectivityChanged or Retry.
      return;
    }
    _load(url);
  }

  /// A link to the bare domain opens the home page in the shopper's own
  /// language, not the site's default-locale redirect.
  String _resolveLink(String url) =>
      url == LinkRouterDelegate.homeLink ? AppUrls.homeFor(_locale) : url;

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
        // successful load clears the overlay (_acceptPage).
        if (await _controller.canGoBack()) {
          _nav.historyRequested();
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
                  if (_needsContentCover && !_loadFailed && !_showOffline)
                    Positioned.fill(
                      child: LoadingScreen(label: strings.loading),
                    ),
                  if (_loadFailed && !_showOffline)
                    Positioned.fill(
                      child: RetryScreen.loadFailed(strings, onRetry: _retry),
                    ),
                  if (_showOffline)
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
