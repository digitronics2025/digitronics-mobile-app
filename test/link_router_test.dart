import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/services/link_router.dart';

void main() {
  tearDown(() => PendingLink.url.value = null);

  test('a plain launch route is not a link', () {
    expect(LinkRouterDelegate.routeToUrl(Uri.parse('/')), isNull);
    expect(LinkRouterDelegate.routeToUrl(Uri()), isNull);
  });

  test('an App Link route becomes the same page on this site', () {
    expect(LinkRouterDelegate.routeToUrl(Uri.parse('/fr/produit/tv-50?ref=share')),
        'https://digitronics.ma/fr/produit/tv-50?ref=share');
  });

  test('setNewRoutePath queues the page for WebViewScreen', () async {
    final delegate = LinkRouterDelegate(home: const SizedBox());
    await delegate.setNewRoutePath(Uri.parse('/ar/promotions'));
    expect(PendingLink.take(), 'https://digitronics.ma/ar/promotions');
    expect(PendingLink.url.value, isNull);
    delegate.dispose();
  });

  test('PendingLink ignores anything that is not this site', () {
    PendingLink.offer('https://evil.example/fr');
    PendingLink.offer('javascript:alert(1)');
    expect(PendingLink.url.value, isNull);
  });
}
