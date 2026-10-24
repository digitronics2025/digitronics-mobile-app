/// What counts as a failed page load. Pure Dart, so the rules are unit-tested
/// (test/page_load_policy_test.dart) without a WebView.
///
/// Before app 1.0.13 the app had none: a page that never arrived left a white
/// screen with the progress bar frozen at 10 % and no way out (October 2026).
library;

enum LoadFailureKind { network, http, timeout }

class LoadFailure {
  const LoadFailure(this.kind, this.detail, this.url);

  final LoadFailureKind kind;

  /// Short machine-ish detail, e.g. `-2 hostLookup net::ERR_NAME_NOT_RESOLVED`.
  final String detail;

  final String url;

  /// One line for the server log (`/api/v1/observability/error`, max 500).
  String describe() {
    final line = '${kind.name}: $detail';
    return line.length > 400 ? line.substring(0, 400) : line;
  }
}

class PageLoadPolicy {
  /// How long a page may take before the app checks whether anything is on
  /// screen. A slow page that already shows content is never replaced.
  static const Duration loadTimeout = Duration(seconds: 20);

  /// How long the content check itself may take (a hung renderer never
  /// answers).
  static const Duration contentCheckTimeout = Duration(seconds: 3);

  /// Script returning 1 when a real https page has visible text, else 0.
  /// WebView's own error page lives at `chrome-error://`, so it never counts.
  static const String contentCheckScript =
      "(location.protocol === 'https:' && document.body && document.body.innerText.trim().length > 0) ? 1 : 0";

  /// True when `runJavaScriptReturningResult` reported visible content. The
  /// result arrives as a num on Android, but the API only promises Object.
  static bool hasContent(Object? result) => result?.toString().trim() == '1';

  /// A main-frame network error ends the load. `ERR_ABORTED` is a navigation
  /// the page or the shopper replaced (or a download), not a failure;
  /// sub-resource errors (an image, a tracker) never blank the page.
  static bool isFatalResourceError({
    required bool? isForMainFrame,
    required String description,
  }) {
    if (isForMainFrame != true) return false;
    return !description.contains('ERR_ABORTED');
  }

  /// HTTP statuses on the main page that mean "nothing useful is on screen".
  /// 404/410 are the site's own designed pages and stay visible; an empty 403
  /// (a block), a 429 and every 5xx render white or a raw error page.
  static bool isFatalHttpStatus(int status) =>
      status == 403 || status == 429 || status >= 500;

  /// Path-only form of a URL for comparing main-frame requests and for logs:
  /// no query (UTM tags, click ids) and no fragment.
  static String stripQuery(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return url;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }
}
