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

  test('pages that differ only by a meaningful query are different pages', () {
    final nav = NavigationTracker(home)
      ..request('https://digitronics.ma/fr/recherche?q=tv')
      ..started('https://digitronics.ma/fr/recherche?q=tv')
      ..request('https://digitronics.ma/fr/recherche?q=frigo')
      ..started('https://digitronics.ma/fr/recherche?q=frigo');
    expect(
      nav.finishedSuccessfully('https://digitronics.ma/fr/recherche?q=tv'),
      isFalse,
    );
    expect(
      nav.isCurrentPage('https://digitronics.ma/fr/recherche?q=tv'),
      isFalse,
    );
    expect(
      nav.finishedSuccessfully('https://digitronics.ma/fr/recherche?q=frigo'),
      isTrue,
    );
  });

  test('generation changes with every new navigation', () {
    final nav = NavigationTracker(home)..request(home);
    final first = nav.generation;
    nav.started(home);
    expect(
      nav.generation,
      first,
      reason: 'the start of a requested load is the same one',
    );
    nav.request(product);
    expect(nav.generation, isNot(first));
  });

  test('Back after a request failed before starting is a fresh navigation', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home)
      ..request(product);
    expect(nav.recordFailure(), isTrue); // failed before onPageStarted
    nav.started(home); // Back: Android starts the history page, no request
    expect(nav.finishedSuccessfully(home), isTrue);
  });

  test('a late start for a request a newer one replaced is ignored', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..request(product); // a notification arrives before home started
    expect(nav.started(home), isFalse, reason: "home's late start is stale");
    expect(nav.awaitingStart, isTrue, reason: 'still waiting for the product');
    expect(nav.target, product);
    expect(nav.finishedSuccessfully(home), isFalse);
    expect(nav.isCurrentPage(productPage), isTrue);
    nav.started(product);
    expect(nav.finishedSuccessfully(product), isTrue);
  });

  test('a stale start stays stale even after the newer page started', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..request(product)
      ..started(product); // B starts first
    nav.started(home); // A's start, delivered late
    expect(nav.target, product);
    expect(nav.finishedSuccessfully(product), isTrue);
  });

  test('a page asked for again after being replaced starts normally', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..request(product)
      ..started(product)
      ..request(home);
    nav.started(home);
    expect(nav.finishedSuccessfully(home), isTrue);
  });

  test('a failure moves the generation, so a pending check cannot undo it', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home);
    final before = nav.generation;
    expect(nav.recordFailure(), isTrue);
    expect(nav.generation, isNot(before));
  });

  test('images and scripts are not the page', () {
    final nav = NavigationTracker(home)
      ..request(home)
      ..started(home);
    expect(
      nav.isCurrentPage('https://digitronics.ma/r2/products/x.webp'),
      isFalse,
    );
    expect(
      nav.isCurrentPage('https://digitronics.ma/fr?utm_source=fb'),
      isTrue,
    );
  });
}
