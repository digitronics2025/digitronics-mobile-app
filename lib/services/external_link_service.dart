import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ExternalLinkService {
  /// Non-http schemes that must be handed to the OS (dialer, mail, WhatsApp…).
  static const _externalSchemes = ['tel', 'mailto', 'sms', 'whatsapp', 'intent'];

  /// Hosts that should open in their dedicated native app (or the browser)
  /// rather than render inside the WebView. Everything else — including any
  /// third-party web page the site redirects to — stays in-app so the
  /// shopping flow is never interrupted by a jump to Chrome.
  static const _externalHosts = [
    'wa.me',
    'api.whatsapp.com',
    'maps.google.com',
    'maps.app.goo.gl',
    'goo.gl',
    'play.google.com',
    'facebook.com',
    'fb.com',
    'instagram.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'youtu.be',
    'tiktok.com',
  ];

  static NavigationDecision handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    if (_externalSchemes.contains(uri.scheme)) {
      _launchExternal(request.url);
      return NavigationDecision.prevent;
    }

    final host = uri.host.toLowerCase();
    final handOffToApp =
        _externalHosts.any((h) => host == h || host.endsWith('.$h'));
    if (handOffToApp) {
      _launchExternal(request.url);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  static Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
