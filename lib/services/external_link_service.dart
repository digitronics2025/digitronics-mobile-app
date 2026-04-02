import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/urls.dart';

class ExternalLinkService {
  static const _externalSchemes = ['tel', 'mailto', 'whatsapp', 'intent', 'sms'];

  static const _externalHosts = [
    'api.whatsapp.com',
    'wa.me',
    'maps.google.com',
    'maps.app.goo.gl',
    'www.google.com',
    'play.google.com',
    'facebook.com',
    'www.facebook.com',
    'instagram.com',
    'www.instagram.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'www.youtube.com',
  ];

  static NavigationDecision handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    if (_externalSchemes.contains(uri.scheme)) {
      _launchExternal(request.url);
      return NavigationDecision.prevent;
    }

    if (_externalHosts.any((host) => uri.host.contains(host))) {
      _launchExternal(request.url);
      return NavigationDecision.prevent;
    }

    if (uri.host.contains(AppUrls.host)) {
      return NavigationDecision.navigate;
    }

    _launchExternal(request.url);
    return NavigationDecision.prevent;
  }

  static Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
