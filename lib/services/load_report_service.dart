import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_info.dart';
import '../constants/urls.dart';

/// Reports pages the app could not show to the site's existing client-error
/// endpoint (`POST /api/v1/observability/error`, `scope: 'app'`), so a phone
/// stuck on a blank screen leaves evidence in `system_logs` instead of none.
///
/// A failure usually means the network is down, so a report that cannot be
/// sent is kept (only the latest one) and sent after the next page that loads.
/// At most one report per message per launch, so a flapping connection cannot
/// flood the endpoint. Never throws.
class LoadReportService {
  static const String _pendingKey = 'pending_load_report';
  static const Duration _timeout = Duration(seconds: 10);
  static final Set<String> _sentThisLaunch = <String>{};

  /// JSON body for the endpoint. Pure, so it is unit-tested.
  static Map<String, Object> buildPayload({
    required String message,
    required String url,
    required String locale,
  }) {
    return {
      'scope': 'app',
      'message': message.length > 500 ? message.substring(0, 500) : message,
      'route': url.length > 500 ? url.substring(0, 500) : url,
      'locale': AppUrls.localeOrDefault(locale),
      'userAgent': appUserAgent('webview-load'),
    };
  }

  static Future<void> report({
    required String message,
    required String url,
    required String locale,
  }) async {
    if (!_sentThisLaunch.add(message)) return;
    final payload = buildPayload(message: message, url: url, locale: locale);
    if (await _post(payload)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingKey, jsonEncode(payload));
    } catch (_) {
      // Storage is best effort too.
    }
  }

  /// Send the report kept from an earlier failure, now that a page loaded.
  static Future<void> flushPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null) return;
      await prefs.remove(_pendingKey);
      final payload = jsonDecode(raw);
      if (payload is Map<String, dynamic>) await _post(payload);
    } catch (_) {
      // A corrupt or unsendable pending report is dropped.
    }
  }

  static Future<bool> _post(Map<String, dynamic> payload) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .postUrl(Uri.parse(AppUrls.errorReportEndpoint))
          .timeout(_timeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.userAgentHeader, appUserAgent('load-report'));
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(_timeout);
      await response.drain<void>().timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
