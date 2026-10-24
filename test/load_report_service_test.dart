import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/constants/app_info.dart';
import 'package:digitronics/services/load_report_service.dart';

void main() {
  test('payload matches the site endpoint contract (scope app, bounded fields)', () {
    final payload = LoadReportService.buildPayload(
      message: 'timeout: no content after 20s (progress 10%)',
      url: 'https://digitronics.ma/ar',
      locale: 'ar',
    );
    expect(payload['scope'], 'app');
    expect(payload['message'], 'timeout: no content after 20s (progress 10%)');
    expect(payload['route'], 'https://digitronics.ma/ar');
    expect(payload['locale'], 'ar');
    expect(payload['userAgent'], 'DigitronicsApp/$kAppVersion (Android; webview-load)');
  });

  test('long values are cut to the endpoint limits and unknown locales fall back', () {
    final payload = LoadReportService.buildPayload(
      message: 'm' * 800,
      url: 'https://digitronics.ma/${'p' * 800}',
      locale: 'de',
    );
    expect((payload['message'] as String).length, 500);
    expect((payload['route'] as String).length, 500);
    expect(payload['locale'], 'fr');
  });
}
