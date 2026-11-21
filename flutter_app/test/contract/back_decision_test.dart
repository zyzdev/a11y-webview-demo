import 'package:a11y_webview_demo/contract/back_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decideBack', () {
    expect(decideBack(webWantsBack: true, webCanGoBack: true), BackAction.askWeb);
    expect(decideBack(webWantsBack: false, webCanGoBack: true), BackAction.webHistoryBack);
    expect(decideBack(webWantsBack: false, webCanGoBack: false), BackAction.popRoute);
    expect(decideBack(webWantsBack: true, webCanGoBack: false), BackAction.askWeb);
  });

  test('routeCanPop', () {
    expect(routeCanPop(webWantsBack: false, webCanGoBack: false), true);
    expect(routeCanPop(webWantsBack: true, webCanGoBack: false), false);
    expect(routeCanPop(webWantsBack: false, webCanGoBack: true), false);
    expect(routeCanPop(webWantsBack: true, webCanGoBack: true), false);
  });

  test('routeCanPop agrees with decideBack in every case', () {
    for (final wants in [true, false]) {
      for (final canGoBack in [true, false]) {
        expect(routeCanPop(webWantsBack: wants, webCanGoBack: canGoBack),
            decideBack(webWantsBack: wants, webCanGoBack: canGoBack) == BackAction.popRoute);
      }
    }
  });
}
