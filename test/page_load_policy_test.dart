import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/services/page_load_policy.dart';

void main() {
  group('isFatalResourceError', () {
    test('a main-frame network error ends the load', () {
      expect(
        PageLoadPolicy.isFatalResourceError(
          isForMainFrame: true,
          description: 'net::ERR_NAME_NOT_RESOLVED',
        ),
        isTrue,
      );
      expect(
        PageLoadPolicy.isFatalResourceError(
          isForMainFrame: true,
          description: 'net::ERR_TOO_MANY_REDIRECTS',
        ),
        isTrue,
      );
    });

    test('sub-resources, unknown frames and aborted navigations do not', () {
      expect(
        PageLoadPolicy.isFatalResourceError(
          isForMainFrame: false,
          description: 'net::ERR_FAILED',
        ),
        isFalse,
      );
      expect(
        PageLoadPolicy.isFatalResourceError(
          isForMainFrame: null,
          description: 'net::ERR_FAILED',
        ),
        isFalse,
      );
      expect(
        PageLoadPolicy.isFatalResourceError(
          isForMainFrame: true,
          description: 'net::ERR_ABORTED',
        ),
        isFalse,
      );
    });
  });

  test('blank or blocked statuses fail; the site\'s own 404 page stays', () {
    for (final status in [403, 429, 500, 502, 503, 520, 522]) {
      expect(
        PageLoadPolicy.isFatalHttpStatus(status),
        isTrue,
        reason: '$status',
      );
    }
    for (final status in [200, 301, 304, 401, 404, 410]) {
      expect(
        PageLoadPolicy.isFatalHttpStatus(status),
        isFalse,
        reason: '$status',
      );
    }
  });

  test('hasContent reads the script result whatever its runtime type', () {
    expect(PageLoadPolicy.hasContent(1), isTrue);
    expect(PageLoadPolicy.hasContent('1'), isTrue);
    expect(PageLoadPolicy.hasContent(0), isFalse);
    expect(PageLoadPolicy.hasContent(null), isFalse);
  });

  test('the content check never counts the WebView error page', () {
    expect(
      PageLoadPolicy.contentCheckScript,
      contains("location.protocol === 'https:'"),
    );
  });

  test('stripQuery drops tracking parameters and fragments', () {
    expect(
      PageLoadPolicy.stripQuery(
        'https://digitronics.ma/fr/produit/x?utm_source=fb&fbclid=1#top',
      ),
      'https://digitronics.ma/fr/produit/x',
    );
    expect(
      PageLoadPolicy.stripQuery('https://digitronics.ma/fr'),
      'https://digitronics.ma/fr',
    );
  });

  test(
    'navigationKey keeps the query that picks the page and drops tracking',
    () {
      expect(
        PageLoadPolicy.navigationKey(
          'https://digitronics.ma/fr/recherche?q=tv',
        ),
        isNot(
          PageLoadPolicy.navigationKey(
            'https://digitronics.ma/fr/recherche?q=frigo',
          ),
        ),
      );
      expect(
        PageLoadPolicy.navigationKey(
          'https://digitronics.ma/fr/recherche?q=tv&utm_source=fb&fbclid=1#top',
        ),
        'https://digitronics.ma/fr/recherche?q=tv',
      );
      expect(
        PageLoadPolicy.navigationKey('https://digitronics.ma/fr?gclid=x'),
        'https://digitronics.ma/fr',
      );
    },
  );

  test('describe stays within the endpoint limit', () {
    final failure = LoadFailure(
      LoadFailureKind.network,
      'x' * 1000,
      'https://digitronics.ma/fr',
    );
    expect(failure.describe().length, lessThanOrEqualTo(400));
    expect(
      const LoadFailure(LoadFailureKind.http, 'status 503', 'u').describe(),
      'http: status 503',
    );
  });
}
