/// Every digitronics.ma address the app uses. Cross-repo contract — a change
/// here must update FLEET.md in the same commit (the server half lives in the
/// DigiTronics.ma repo).
class AppUrls {
  static const String host = 'digitronics.ma';
  static const String baseUrl = 'https://$host';

  /// The storefront's locale roots. The app opens one of these directly: the
  /// bare domain only answers a 301 to `/fr`, which cost every launch an extra
  /// round trip and an extra Worker request.
  static const List<String> locales = ['fr', 'ar', 'en'];
  static const String defaultLocale = 'fr';

  static const String pushRegisterEndpoint = '$baseUrl/api/v1/push/register';

  /// Page-load failure reports (`scope: 'app'`), logged as warnings.
  static const String errorReportEndpoint = '$baseUrl/api/v1/observability/error';

  /// `fr`, `ar` or `en`; anything else falls back to [defaultLocale].
  static String localeOrDefault(String? code) {
    final c = code?.toLowerCase();
    return (c != null && locales.contains(c)) ? c : defaultLocale;
  }

  /// The home page for a locale, e.g. `https://digitronics.ma/ar`.
  static String homeFor(String? localeCode) =>
      '$baseUrl/${localeOrDefault(localeCode)}';

  /// The storefront locale a URL is on (`/ar/produit/…` → `ar`), or null.
  static String? localeOf(Uri uri) {
    if (!isOwnSite(uri) || uri.pathSegments.isEmpty) return null;
    final first = uri.pathSegments.first.toLowerCase();
    return locales.contains(first) ? first : null;
  }

  /// True for https pages on digitronics.ma or www.digitronics.ma.
  static bool isOwnSite(Uri uri) =>
      uri.scheme == 'https' && (uri.host == host || uri.host == 'www.$host');

  /// The in-app URL for a link from outside the WebView (a notification
  /// payload, an App Link, a deep-link route): an absolute https URL on this
  /// site, or a site path such as `/fr/produit/x`. Anything else — another
  /// host, `http:`, `javascript:`, `intent:` — returns null and is ignored, so
  /// a crafted payload can never load a foreign page with the app's privileges.
  static String? inAppUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (!uri.hasScheme && !uri.hasAuthority && value.startsWith('/') &&
        !value.startsWith('//')) {
      return Uri.parse(baseUrl).resolveUri(uri).toString();
    }
    return isOwnSite(uri) ? uri.toString() : null;
  }
}
