import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/l10n/app_strings.dart';

void main() {
  test('French, Arabic and English, with French as the fallback', () {
    expect(AppStrings.of('fr').retry, 'Réessayer');
    expect(AppStrings.of('ar').isRtl, isTrue);
    expect(AppStrings.of('en').retry, 'Try again');
    expect(AppStrings.of('de').languageCode, 'fr');
    expect(AppStrings.of(null).languageCode, 'fr');
  });

  test('every language defines every string', () {
    for (final code in ['fr', 'ar', 'en']) {
      final s = AppStrings.of(code);
      for (final value in [
        s.offlineTitle, s.offlineBody, s.failedTitle, s.failedBody,
        s.retry, s.loading, s.pressAgainToExit,
      ]) {
        expect(value, isNotEmpty);
      }
    }
  });
}
