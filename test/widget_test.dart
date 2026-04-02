import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/constants/urls.dart';

void main() {
  test('AppUrls has correct base URL', () {
    expect(AppUrls.baseUrl, 'https://digitronics.ma');
  });
}
