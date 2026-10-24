import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/urls.dart';

/// The one queue for "open this page" requests that come from outside the
/// WebView: a tapped notification, or a digitronics.ma App Link. WebViewScreen
/// listens and loads the URL. Only this site's https pages are accepted
/// ([AppUrls.inAppUrl]).
class PendingLink {
  static final ValueNotifier<String?> url = ValueNotifier<String?>(null);

  static void offer(String? raw) {
    final inApp = AppUrls.inAppUrl(raw);
    if (inApp != null) url.value = inApp;
  }

  /// Take the pending URL, if any, and clear it.
  static String? take() {
    final value = url.value;
    url.value = null;
    return value;
  }
}

/// Feeds Flutter's built-in deep linking into [PendingLink]. Android hands an
/// App Link (`https://digitronics.ma/fr/produit/x`) to Flutter as the route
/// `/fr/produit/x`, at launch and while running; before 1.0.13 nothing read it
/// and every link opened the home page.
class LinkRouteParser extends RouteInformationParser<Uri> {
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture<Uri>(routeInformation.uri);
}

class LinkRouterDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  LinkRouterDelegate({required this.home});

  /// The app's only screen.
  final Widget home;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// `/` (a plain launch) is not a link; any other path, query or `#section`
  /// is, and all three are kept so the tapped section opens.
  static String? routeToUrl(Uri route) {
    final path = route.path.isEmpty ? '/' : route.path;
    if (path == '/' && !route.hasQuery && !route.hasFragment) return null;
    return AppUrls.inAppUrl(
      Uri(
        path: path,
        query: route.hasQuery ? route.query : null,
        fragment: route.hasFragment ? route.fragment : null,
      ).toString(),
    );
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    PendingLink.offer(routeToUrl(configuration));
    return SynchronousFuture<void>(null);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [MaterialPage<void>(child: home)],
      // The single page never pops: WebViewScreen's PopScope handles back.
      onDidRemovePage: (_) {},
    );
  }
}
