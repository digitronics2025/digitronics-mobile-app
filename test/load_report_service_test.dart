import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digitronics/constants/app_info.dart';
import 'package:digitronics/services/load_report_service.dart';

void main() {
  test(
    'payload matches the site endpoint contract (scope app, bounded fields)',
    () {
      final payload = LoadReportService.buildPayload(
        message: 'timeout: no content after 20s (progress 10%)',
        url: 'https://digitronics.ma/ar',
        locale: 'ar',
      );
      expect(payload['scope'], 'app');
      expect(
        payload['message'],
        'timeout: no content after 20s (progress 10%)',
      );
      expect(payload['route'], 'https://digitronics.ma/ar');
      expect(payload['locale'], 'ar');
      expect(
        payload['userAgent'],
        'DigitronicsApp/$kAppVersion (Android; webview-load)',
      );
    },
  );

  test(
    'long values are cut to the endpoint limits and unknown locales fall back',
    () {
      final payload = LoadReportService.buildPayload(
        message: 'm' * 800,
        url: 'https://digitronics.ma/${'p' * 800}',
        locale: 'de',
      );
      expect((payload['message'] as String).length, 500);
      expect((payload['route'] as String).length, 500);
      expect(payload['locale'], 'fr');
    },
  );

  group('flushPending', () {
    const key = 'pending_load_report';
    final saved = jsonEncode({'scope': 'app', 'message': 'timeout'});

    test(
      'keeps the saved report while the endpoint still refuses it',
      () async {
        SharedPreferences.setMockInitialValues({key: saved});
        var calls = 0;
        await LoadReportService.flushPending(
          send: (_) async {
            calls++;
            return false;
          },
        );
        expect(calls, 1);
        expect((await SharedPreferences.getInstance()).getString(key), saved);
      },
    );

    test('removes it once the site accepted it', () async {
      SharedPreferences.setMockInitialValues({key: saved});
      Map<String, dynamic>? sent;
      await LoadReportService.flushPending(
        send: (p) async {
          sent = p;
          return true;
        },
      );
      expect(sent?['message'], 'timeout');
      expect((await SharedPreferences.getInstance()).getString(key), isNull);
    });

    test('drops a corrupt saved report without sending it', () async {
      SharedPreferences.setMockInitialValues({key: 'not json'});
      var calls = 0;
      await LoadReportService.flushPending(
        send: (_) async {
          calls++;
          return true;
        },
      );
      expect(calls, 0);
      expect((await SharedPreferences.getInstance()).getString(key), isNull);
    });
  });
}
