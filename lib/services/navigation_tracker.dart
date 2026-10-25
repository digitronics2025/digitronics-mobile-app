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
  int _generation = 0;
  bool _awaitingStart = false;
  String _target;
  String _requestedPage = '';
  String _startedPage = '';

  /// Pages requested earlier and replaced by a newer request before they
  /// started. A later start for one of them is stale — even after the newer
  /// page started — except the start of a Back the app performed
  /// ([historyRequested]), which may reach an older entry with the same URL.
  /// A page leaves the set when it is requested again; the set keeps the most
  /// recent [_maxSuperseded] entries.
  final Set<String> _supersededPages = <String>{};
  static const int _maxSuperseded = 8;

  /// Set by [historyRequested] when the app itself goes Back: the next start
  /// is a history entry, which may share its URL with a replaced request.
  bool _expectHistoryStart = false;

  /// The page a retry should load: the latest one asked for.
  String get target => _target;

  /// Changes whenever a new navigation opens or the current one fails. An
  /// async check (a content probe) captures it first and drops its result if
  /// it changed meanwhile, so a late answer can neither fail a newer page nor
  /// undo a failure.
  int get generation => _generation;

  /// True between a request and its page's start: the WebView may still be
  /// showing the previous page.
  bool get awaitingStart => _awaitingStart;

  /// A main-frame load of [url] was asked for, by the app (`loadRequest`) or
  /// by the page (a link, a redirect).
  void request(String url) {
    final page = PageLoadPolicy.navigationKey(url);
    if (_awaitingStart && _requestedPage != page) {
      _supersededPages.add(_requestedPage);
      if (_supersededPages.length > _maxSuperseded) {
        _supersededPages.remove(_supersededPages.first);
      }
    }
    _supersededPages.remove(page); // Asked for again: its start is real.
    _id++;
    _generation++;
    _awaitingStart = true;
    _target = url;
    _requestedPage = page;
  }

  /// `onPageStarted`. A start with no request before it (Android does not
  /// always ask first, e.g. history navigation) opens its own navigation —
  /// also when the awaited request already failed and a different page starts
  /// (Back from the retry screen), so the failed request's mark never sticks
  /// to it. The failed request's own late start stays failed, and a late
  /// start for a request a newer one replaced is ignored.
  ///
  /// Returns false when the start was rejected as stale, so the caller does
  /// not treat it as activity of the current navigation.
  bool started(String url) {
    final page = PageLoadPolicy.navigationKey(url);
    // A late start for a request that a newer one replaced: not this load —
    // unless the app just went Back, whose history entry may share the URL.
    final isHistory = _expectHistoryStart;
    _expectHistoryStart = false;
    if (!isHistory &&
        page != _requestedPage &&
        _supersededPages.contains(page)) {
      return false;
    }
    if (isHistory) _supersededPages.remove(page);
    final supersedesFailedRequest =
        _awaitingStart && _failedId == _id && page != _requestedPage;
    if (!_awaitingStart || supersedesFailedRequest) {
      _id++;
      _generation++;
    }
    _awaitingStart = false;
    _startedPage = page;
    if (url.startsWith('https://')) _target = url;
    return true;
  }

  /// `onPageFinished` for [url]: true only when it completes the current
  /// navigation without a recorded failure. Android still "finishes" its own
  /// error page, and the previous page may finish after a new request or even
  /// after the new page started — so the URL must be the started page's.
  bool finishedSuccessfully(String url) =>
      !_awaitingStart &&
      _failedId != _id &&
      PageLoadPolicy.navigationKey(url) == _startedPage;

  /// Whether a resource error for [url] concerns the page being opened — not
  /// an image or script inside it, nor the page being left. Until the new page
  /// starts only the requested page counts; after that only the started one.
  bool isCurrentPage(String url) {
    final page = PageLoadPolicy.navigationKey(url);
    return page == (_awaitingStart ? _requestedPage : _startedPage);
  }

  /// The app is about to go Back (`goBack()`): the next start is a history
  /// navigation and must be tracked even if its URL matches a replaced
  /// request.
  void historyRequested() => _expectHistoryStart = true;

  /// Record that the current navigation failed. False when it was already
  /// recorded, so one navigation is handled once.
  bool recordFailure() {
    if (_failedId == _id) return false;
    _failedId = _id;
    _generation++;
    return true;
  }
}
