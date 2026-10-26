import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:digitronics/services/app_bridge.dart';

void main() {
  test('publishes platform, version and token as a frozen JSON literal', () {
    final js = AppBridge.script(version: '1.0.14', token: 'abc:DEF_123');
    expect(js, startsWith('window.__digitronicsApp=Object.freeze('));
    final json = js.substring(js.indexOf('(') + 1, js.indexOf(');'));
    expect(jsonDecode(json), {'platform': 'android', 'version': '1.0.14', 'fcmToken': 'abc:DEF_123'});
    expect(js, contains("dispatchEvent(new Event('digitronics:app-bridge'))"));
  });

  test('omits a missing token', () {
    final js = AppBridge.script(version: '1.0.14');
    expect(js, isNot(contains('fcmToken')));
  });

  test('cannot be broken out of by a hostile value', () {
    final js = AppBridge.script(version: "1');alert(1);//", token: '"</script>');
    final json = js.substring(js.indexOf('(') + 1, js.lastIndexOf(');window'));
    expect((jsonDecode(json) as Map)['version'], "1');alert(1);//");
  });
}
