import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/constants/urls.dart';

void main() {
  test('AppUrls has correct base URL', () {
    expect(AppUrls.baseUrl, 'https://digitronics.ma');
  });

  group('locale roots', () {
    test('opens the locale page directly, never the redirecting bare domain', () {
      expect(AppUrls.homeFor('ar'), 'https://digitronics.ma/ar');
      expect(AppUrls.homeFor('EN'), 'https://digitronics.ma/en');
      expect(AppUrls.homeFor('fr'), 'https://digitronics.ma/fr');
      expect(AppUrls.homeFor('de'), 'https://digitronics.ma/fr');
      expect(AppUrls.homeFor(null), 'https://digitronics.ma/fr');
    });

    test('reads the storefront locale from a site URL', () {
      expect(AppUrls.localeOf(Uri.parse('https://digitronics.ma/ar/produit/x')), 'ar');
      expect(AppUrls.localeOf(Uri.parse('https://www.digitronics.ma/en')), 'en');
      expect(AppUrls.localeOf(Uri.parse('https://digitronics.ma/panier')), isNull);
      expect(AppUrls.localeOf(Uri.parse('https://example.com/ar')), isNull);
    });
  });

  group('inAppUrl', () {
    test('accepts this site (https, with or without www) and site paths', () {
      expect(AppUrls.inAppUrl('https://digitronics.ma/fr/produit/tv?x=1'),
          'https://digitronics.ma/fr/produit/tv?x=1');
      expect(AppUrls.inAppUrl('https://www.digitronics.ma/ar'),
          'https://www.digitronics.ma/ar');
      expect(AppUrls.inAppUrl(' /fr/promotions '),
          'https://digitronics.ma/fr/promotions');
    });

    test('refuses foreign hosts, plain http, scripts and protocol-relative links', () {
      expect(AppUrls.inAppUrl('https://evil.example/fr'), isNull);
      expect(AppUrls.inAppUrl('https://digitronics.ma.evil.example/fr'), isNull);
      expect(AppUrls.inAppUrl('http://digitronics.ma/fr'), isNull);
      expect(AppUrls.inAppUrl('javascript:alert(1)'), isNull);
      expect(AppUrls.inAppUrl('intent://scan#Intent;end'), isNull);
      expect(AppUrls.inAppUrl('//evil.example/x'), isNull);
      expect(AppUrls.inAppUrl(''), isNull);
      expect(AppUrls.inAppUrl(null), isNull);
    });
  });
}
