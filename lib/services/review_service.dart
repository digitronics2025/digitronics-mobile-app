import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const String _openCountKey = 'app_open_count';
  static const String _reviewPromptedKey = 'review_prompted';
  static const int _openThreshold = 5;

  static Future<void> checkAndPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyPrompted = prefs.getBool(_reviewPromptedKey) ?? false;
    if (alreadyPrompted) return;

    final openCount = (prefs.getInt(_openCountKey) ?? 0) + 1;
    await prefs.setInt(_openCountKey, openCount);

    if (openCount >= _openThreshold) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool(_reviewPromptedKey, true);
      }
    }
  }
}
