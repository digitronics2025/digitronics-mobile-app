import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:digitronics/app.dart';
import 'package:digitronics/constants/app_info.dart';
import 'package:digitronics/screens/retry_screen.dart';
import 'package:digitronics/services/link_router.dart';

/// Drives the real WebViewScreen against a scripted fake WebView, to prove the
/// October 2026 white screen cannot come back: a page that fails or never
/// arrives ends on a retry screen, never on a blank one.

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;
  HttpResponseErrorCallback? onHttpError;
  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback cb) async => onPageStarted = cb;
  @override
  Future<void> setOnPageFinished(PageEventCallback cb) async => onPageFinished = cb;
  @override
  Future<void> setOnProgress(ProgressCallback cb) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback cb) async =>
      onWebResourceError = cb;
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback cb) async => onHttpError = cb;
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback cb) async =>
      onNavigationRequest = cb;
  @override
  Future<void> setOnUrlChange(UrlChangeCallback cb) async {}
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  FakeNavigationDelegate? delegate;
  final List<String> loads = <String>[];
  int cacheClears = 0;
  Object contentResult = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as FakeNavigationDelegate;
  @override
  Future<void> loadRequest(LoadRequestParams params) async => loads.add(params.uri.toString());
  @override
  Future<void> clearCache() async => cacheClears++;
  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => contentResult;
  bool hasHistory = false;
  int backs = 0;

  @override
  Future<bool> canGoBack() async => hasHistory;
  @override
  Future<void> goBack() async => backs++;

  /// What Android reports for a main-frame network error.
  void failMainFrame(String url) {
    delegate!.onPageStarted?.call(url);
    delegate!.onWebResourceError?.call(WebResourceError(
      errorCode: -2,
      description: 'net::ERR_NAME_NOT_RESOLVED',
      errorType: WebResourceErrorType.hostLookup,
      isForMainFrame: true,
      url: url,
    ));
    delegate!.onPageFinished?.call(url); // Android finishes its error page.
  }

  void succeed(String url) {
    delegate!.onPageStarted?.call(url);
    delegate!.onPageFinished?.call(url);
  }
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class FakeWebViewPlatform extends WebViewPlatform {
  FakeWebViewController? controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
          PlatformWebViewControllerCreationParams params) =>
      controller = FakeWebViewController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeNavigationDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      FakeWebViewWidget(params);
}

const _connectivityMethod = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _connectivityEvents = EventChannel('dev.fluttercommunity.plus/connectivity_status');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWebViewPlatform platform;
  late List<String> connectivity;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    connectivity = ['wifi'];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_connectivityMethod, (call) async => connectivity);
    messenger.setMockStreamHandler(
        _connectivityEvents, MockStreamHandler.inline(onListen: (_, _) {}));
    PendingLink.url.value = null;
  });

  Future<FakeWebViewController> launch(WidgetTester tester,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(const DigitronicsApp());
    await tester.pump(const Duration(milliseconds: 50));
    return platform.controller!;
  }

  /// Let the splash animations and timers run out, so no timer is left.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('opens the locale page directly and clears the cache once after the update',
      (tester) async {
    final c = await launch(tester, prefs: {'last_locale': 'ar'});
    expect(c.loads, ['https://digitronics.ma/ar']);
    expect(c.cacheClears, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('webview_cache_epoch'), kWebViewCacheEpoch);
    c.succeed('https://digitronics.ma/ar');
    await settle(tester);
    expect(find.byType(RetryScreen), findsNothing);
  });

  testWidgets('does not clear the cache again on later launches', (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    expect(c.cacheClears, 0);
    c.succeed(c.loads.single);
    await settle(tester);
  });

  testWidgets('first failure clears the cache and retries silently; the second shows retry',
      (tester) async {
    final c = await launch(tester,
        prefs: {'webview_cache_epoch': kWebViewCacheEpoch, 'last_locale': 'fr'});
    final url = c.loads.single;

    c.failMainFrame(url);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.cacheClears, 1, reason: 'automatic recovery clears the HTTP cache');
    expect(c.loads, [url, url], reason: 'and reloads the same page');
    expect(find.byType(RetryScreen), findsNothing);

    c.failMainFrame(url);
    await settle(tester);
    expect(find.byType(RetryScreen), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    // Retry: cache cleared again, page reloaded, retry screen gone on success.
    await tester.tap(find.text('Réessayer'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.cacheClears, 2);
    expect(c.loads.length, 3);
    c.succeed(url);
    await settle(tester);
    expect(find.byType(RetryScreen), findsNothing);
  });

  testWidgets('Back from the retry screen returns to the previous page', (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    const home = 'https://digitronics.ma/fr';
    const product = 'https://digitronics.ma/fr/produit/tv';
    c.succeed(c.loads.single);
    await settle(tester);
    c.hasHistory = true;
    c.failMainFrame(product); // silent recovery
    await tester.pump(const Duration(milliseconds: 50));
    c.failMainFrame(product); // retry screen
    await settle(tester);
    expect(find.byType(RetryScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(c.backs, 1, reason: 'Back goes to the previous page, not the exit prompt');
    c.succeed(home);
    await settle(tester);
    expect(find.byType(RetryScreen), findsNothing);
  });

  testWidgets('a page that never arrives ends on the retry screen, not white',
      (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    c.delegate!.onPageStarted?.call(c.loads.single);
    // Nothing else ever happens (the screenshot: stuck at 10 %).
    await tester.pump(const Duration(seconds: 21)); // watchdog → silent recovery
    expect(c.cacheClears, 1);
    await tester.pump(const Duration(seconds: 21)); // second timeout → retry screen
    await settle(tester);
    expect(find.byType(RetryScreen), findsOneWidget);
  });

  testWidgets('a slow page that already shows content is never replaced', (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    c.contentResult = 1;
    c.delegate!.onPageStarted?.call(c.loads.single);
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    expect(c.cacheClears, 0);
    expect(find.byType(RetryScreen), findsNothing);
    expect(find.byType(LoadingScreen), findsNothing);
  });

  testWidgets('an empty 403 or a 5xx on the page fails; on an image it does not',
      (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    final url = c.loads.single;
    c.delegate!.onPageStarted?.call(url);
    c.delegate!.onHttpError?.call(HttpResponseError(
      request: WebResourceRequest(uri: Uri.parse('https://digitronics.ma/r2/x.webp')),
      response: const WebResourceResponse(uri: null, statusCode: 503),
    ));
    expect(c.cacheClears, 0, reason: 'a sub-resource error is not a page failure');
    c.delegate!.onHttpError?.call(HttpResponseError(
      request: WebResourceRequest(uri: Uri.parse(url)),
      response: const WebResourceResponse(uri: null, statusCode: 403),
    ));
    c.delegate!.onPageFinished?.call(url);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.cacheClears, 1);
    expect(c.loads.length, 2);
    c.succeed(url);
    await settle(tester);
  });

  testWidgets('offline at launch shows the offline screen instead of loading',
      (tester) async {
    connectivity = ['none'];
    final c = await launch(tester,
        prefs: {'webview_cache_epoch': kWebViewCacheEpoch, 'last_locale': 'fr'});
    await settle(tester);
    expect(c.loads, isEmpty);
    expect(find.text('Pas de connexion Internet'), findsOneWidget);
  });

  testWidgets('a notification or App Link opens that page; foreign links are ignored',
      (tester) async {
    final c = await launch(tester, prefs: {'webview_cache_epoch': kWebViewCacheEpoch});
    c.succeed(c.loads.single);
    PendingLink.offer('https://evil.example/fr');
    PendingLink.offer('/fr/produit/tv-50');
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.loads.last, 'https://digitronics.ma/fr/produit/tv-50');
    expect(c.loads.length, 2);
    await settle(tester);
  });
}
