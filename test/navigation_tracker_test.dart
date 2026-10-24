import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/services/navigation_tracker.dart';

void main() {
  const home = 'https://digitronics.ma/fr';
  const product = 'https://digitronics.ma/fr/produit/tv?utm_source=fb';

  test('a normal load: request, start, finish succeeds once', () {
    final nav = NavigationTracker(home)..request(home);
    expect(nav.finishedSuccessfully(), isFalse, reason: 'not started yet');
    nav.started(home);
    expect(nav.finishedSuccessfully(), isTrue);
  });

  test('an error before onPageStarted is pinned to the page being opened', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home);
    expect(nav.finishedSuccessfully(), isTrue);

    // The page follows a link; Android reports its 503 before it "starts".
    nav.request(product);
    expect(
      nav.isCurrentPage('https://digitronics.ma/fr/produit/tv'),
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
    expect(nav.finishedSuccessfully(), isFalse);
  });

  test('the previous page finishing after a new request is not a success', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home)
      ..request(product);
    expect(nav.finishedSuccessfully(), isFalse);
    nav.started(product);
    expect(nav.finishedSuccessfully(), isTrue);
  });

  test('a retry after a failure opens a fresh navigation that can succeed', () {
    final nav = NavigationTracker(home)
      ..request(product)
      ..started(product);
    expect(nav.recordFailure(), isTrue);
    nav
      ..request(nav.target)
      ..started(product);
    expect(nav.finishedSuccessfully(), isTrue);
  });

  test(
    'a start with no request (history navigation) is its own navigation',
    () {
      final nav = NavigationTracker(home)
        ..request(product)
        ..started(product);
      expect(nav.recordFailure(), isTrue);
      nav.started(home); // Back
      expect(nav.finishedSuccessfully(), isTrue);
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
