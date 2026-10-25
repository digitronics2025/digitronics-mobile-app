/// The few native strings the app shows itself (everything else is the
/// website). French, Arabic and English, picked from the storefront locale the
/// shopper last used, else the phone's language.
class AppStrings {
  const AppStrings._(this.languageCode);

  final String languageCode;

  factory AppStrings.of(String? languageCode) =>
      AppStrings._(_values.containsKey(languageCode) ? languageCode! : 'fr');

  static const Map<String, Map<String, String>> _values = {
    'fr': {
      'offlineTitle': 'Pas de connexion Internet',
      'offlineBody': 'Vérifiez votre connexion et réessayez.',
      'failedTitle': 'La page ne s’est pas chargée',
      'failedBody':
          'La connexion au magasin a échoué. Réessayez : l’application vide son cache et recharge.',
      'retry': 'Réessayer',
      'loading': 'Chargement…',
      'pressAgainToExit': 'Appuyez à nouveau pour quitter',
    },
    'ar': {
      'offlineTitle': 'لا يوجد اتصال بالإنترنت',
      'offlineBody': 'تحقق من اتصالك ثم أعد المحاولة.',
      'failedTitle': 'لم يتم تحميل الصفحة',
      'failedBody':
          'تعذر الاتصال بالمتجر. أعد المحاولة: سيقوم التطبيق بمسح ذاكرة التخزين المؤقت وإعادة التحميل.',
      'retry': 'إعادة المحاولة',
      'loading': 'جارٍ التحميل…',
      'pressAgainToExit': 'اضغط مرة أخرى للخروج',
    },
    'en': {
      'offlineTitle': 'No internet connection',
      'offlineBody': 'Check your connection and try again.',
      'failedTitle': 'The page did not load',
      'failedBody':
          'Could not reach the shop. Try again: the app clears its cache and reloads.',
      'retry': 'Try again',
      'loading': 'Loading…',
      'pressAgainToExit': 'Press again to exit',
    },
  };

  bool get isRtl => languageCode == 'ar';

  String _t(String key) => _values[languageCode]![key]!;

  String get offlineTitle => _t('offlineTitle');
  String get offlineBody => _t('offlineBody');
  String get failedTitle => _t('failedTitle');
  String get failedBody => _t('failedBody');
  String get retry => _t('retry');
  String get loading => _t('loading');
  String get pressAgainToExit => _t('pressAgainToExit');
}
