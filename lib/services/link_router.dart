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

  /// A link to the bare domain while the app runs. WebViewScreen opens it
  /// as the home page in the shopper's language.
  static const String homeLink = '${AppUrls.baseUrl}/';

  /// Any path, query or `#section` is a link, and all three are kept so the
  /// tapped section opens. A bare `/` is a link only after launch
  /// ([rootIsLink]): at launch it is just the default route.
  static String? routeToUrl(Uri route, {bool rootIsLink = false}) {
    final path = route.path.isEmpty ? '/' : route.path;
    if (path == '/' && !route.hasQuery && !route.hasFragment) {
      return rootIsLink ? homeLink : null;
    }
    return AppUrls.inAppUrl(
      Uri(
        path: path,
        query: route.hasQuery ? route.query : null,
        fragment: route.hasFragment ? route.fragment : null,
      ).toString(),
    );
  }

  /// The launch route: `/` for a plain launch, or the App Link that opened
  /// the app.
  @override
  Future<void> setInitialRoutePath(Uri configuration) {
    PendingLink.offer(routeToUrl(configuration));
    return SynchronousFuture<void>(null);
  }

  /// A route pushed while the app runs is always an App Link, including
  /// `https://digitronics.ma/` (route `/`).
  @override
  Future<void> setNewRoutePath(Uri configuration) {
    PendingLink.offer(routeToUrl(configuration, rootIsLink: true));
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
