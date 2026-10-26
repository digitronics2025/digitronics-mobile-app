/// The app version, kept equal to `version:` in pubspec.yaml (without the
/// `+build` suffix) by test/app_info_test.dart. Sent in the User-Agent of the
/// app's own requests so server logs can tell releases apart.
const String kAppVersion = '1.0.14';

/// User-Agent for the app's native HTTP calls (not the WebView's).
String appUserAgent(String purpose) =>
    'DigitronicsApp/$kAppVersion (Android; $purpose)';

/// Bump to make every phone clear its WebView HTTP cache once on the next
/// launch after updating. 1 (app 1.0.13): drops redirects the site cached for
/// a year in October 2026, see docs/GUIDE.md §11.
const int kWebViewCacheEpoch = 1;
