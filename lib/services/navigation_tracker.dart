import 'page_load_policy.dart';

/// Which main-frame navigation the WebView's callbacks belong to. Pure Dart,
/// unit-tested in test/navigation_tracker_test.dart.
///
/// Android reports a navigation in an order that is not always "request,
/// started, finished": an HTTP or network error can arrive before
/// `onPageStarted`, and the previous page can still "finish" after a new load
/// was requested. Every load — one the app starts, or a link the page itself
/// follows — therefore opens a new navigation at request time, so an early
/// error is pinned to the page being opened (and a retry reloads that page),
/// and a stale finish is never taken for success.
class NavigationTracker {
  NavigationTracker(this._target);

  int _id = 0;
  int _failedId = -1;
  bool _awaitingStart = false;
  String _target;
  String _requestedPage = '';
  String _startedPage = '';

  /// The page a retry should load: the latest one asked for.
  String get target => _target;

  /// A main-frame load of [url] was asked for, by the app (`loadRequest`) or
  /// by the page (a link, a redirect).
  void request(String url) {
    _id++;
    _awaitingStart = true;
    _target = url;
    _requestedPage = PageLoadPolicy.stripQuery(url);
  }

  /// `onPageStarted`. A start with no request before it (Android does not
  /// always ask first, e.g. history navigation) opens its own navigation.
  void started(String url) {
    if (!_awaitingStart) _id++;
    _awaitingStart = false;
    _startedPage = PageLoadPolicy.stripQuery(url);
    if (url.startsWith('https://')) _target = url;
  }

  /// `onPageFinished` for [url]: true only when it completes the current
  /// navigation without a recorded failure. Android still "finishes" its own
  /// error page, and the previous page may finish after a new request or even
  /// after the new page started — so the URL must be the started page's.
  bool finishedSuccessfully(String url) =>
      !_awaitingStart &&
      _failedId != _id &&
      PageLoadPolicy.stripQuery(url) == _startedPage;

  /// Whether a resource error for [url] concerns the page being opened — not
  /// an image or script inside it, nor the page being left. Until the new page
  /// starts only the requested page counts; after that only the started one.
  bool isCurrentPage(String url) {
    final page = PageLoadPolicy.stripQuery(url);
    return page == (_awaitingStart ? _requestedPage : _startedPage);
  }

  /// Record that the current navigation failed. False when it was already
  /// recorded, so one navigation is handled once.
  bool recordFailure() {
    if (_failedId == _id) return false;
    _failedId = _id;
    return true;
  }
}
