import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/services/navigation_tracker.dart';

void main() {
  const home = 'https://digitronics.ma/fr';
  const product = 'https://digitronics.ma/fr/produit/tv?utm_source=fb';
  const productPage = 'https://digitronics.ma/fr/produit/tv';

  test('a normal load: request, start, finish succeeds', () {
    final nav = NavigationTracker(home)..request(home);
    expect(nav.finishedSuccessfully(home), isFalse, reason: 'not started yet');
    nav.started(home);
    expect(nav.finishedSuccessfully(home), isTrue);
  });

  test('an error before onPageStarted is pinned to the page being opened', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home);

    // The page follows a link; Android reports its 503 before it "starts".
    nav.request(product);
    expect(
      nav.isCurrentPage(productPage),
      isTrue,
      reason: 'matched without the tracking query',
    );
    expect(nav.recordFailure(), isTrue);
    expect(
      nav.target,
      product,
      reason: 'a retry reloads the failed page, not home',
    );
    expect(nav.recordFailure(), isFalse, reason: 'one failure per navigation');

    // The failed navigation's own late finish is not a success.
    nav.started(product);
    expect(nav.finishedSuccessfully(product), isFalse);
  });

  test('a late error for the page being left never fails the new page', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home)
      ..request(product);
    expect(nav.isCurrentPage(home), isFalse, reason: 'before the new start');
    nav.started(product);
    expect(nav.isCurrentPage(home), isFalse, reason: 'after the new start');
    expect(nav.isCurrentPage(productPage), isTrue);
  });

  test('the previous page finishing late is never the new page succeeding', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home)
      ..request(product);
    expect(nav.finishedSuccessfully(home), isFalse, reason: 'before the start');
    nav.started(product);
    expect(nav.finishedSuccessfully(home), isFalse, reason: 'after the start');
    expect(nav.finishedSuccessfully(product), isTrue);
  });

  test('a retry after a failure opens a fresh navigation that can succeed', () {
    final nav = NavigationTracker(home)
      ..request(product)
      ..started(product);
    expect(nav.recordFailure(), isTrue);
    nav
      ..request(nav.target)
      ..started(product);
    expect(nav.finishedSuccessfully(product), isTrue);
  });

  test(
    'a start with no request (history navigation) is its own navigation',
    () {
      final nav = NavigationTracker(home)
        ..request(product)
        ..started(product);
      expect(nav.recordFailure(), isTrue);
      nav.started(home); // Back
      expect(nav.finishedSuccessfully(home), isTrue);
      expect(nav.target, home);
    },
  );

  test('images and scripts are not the page', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home);
    expect(
      nav.isCurrentPage('https://digitronics.ma/r2/products/x.webp'),
      isFalse,
    );
    expect(nav.isCurrentPage('https://digitronics.ma/fr?x=1'), isTrue);
  });
}
