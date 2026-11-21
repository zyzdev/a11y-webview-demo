import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('effectiveTextScaleStrategy：「網頁負責」只套用在自家網域', () {
    expect(effectiveTextScaleStrategy(TextScaleStrategy.webOwned, trustedPage: true), TextScaleStrategy.webOwned);
    expect(effectiveTextScaleStrategy(TextScaleStrategy.webOwned, trustedPage: false), TextScaleStrategy.appOwned);
    expect(effectiveTextScaleStrategy(TextScaleStrategy.appOwned, trustedPage: false), TextScaleStrategy.appOwned);
    expect(effectiveTextScaleStrategy(TextScaleStrategy.none, trustedPage: false), TextScaleStrategy.none);
  });

  test('copyWith 只改指定的欄位', () {
    expect(DemoWebViewConfig.baseline.copyWith(passTheme: false).passTheme, false);
    expect(DemoWebViewConfig.baseline.copyWith(passTheme: false).passLang, true);
  });

  test('baseline 的預設值', () {
    const c = DemoWebViewConfig.baseline;
    expect(c.textScale, TextScaleStrategy.webOwned);
    expect(c.passTheme, true);
    expect(c.passA11yPrefs, true);
    expect(c.passLang, true);
    expect(c.langOverride, isNull);
    expect(c.titleFromWeb, true);
    expect(c.arrival, ArrivalAnnounce.none);
    expect(c.syncBackWithWeb, true);
    expect(c.accessibleLoadingAndError, true);
    expect(c.handleJsDialogs, true);
    expect(c.handleExternalNavigation, true);
    expect(c.enableZoom, true);
    expect(c.androidHybridComposition, isNull);
  });

  test('copyWith 每個欄位都能單獨改，其餘保持不變', () {
    const b = DemoWebViewConfig.baseline;
    final changed = b.copyWith(
      textScale: TextScaleStrategy.none,
      passTheme: false,
      passA11yPrefs: false,
      passLang: false,
      langOverride: 'en',
      titleFromWeb: false,
      arrival: ArrivalAnnounce.sendAnnouncement,
      syncBackWithWeb: false,
      accessibleLoadingAndError: false,
      handleJsDialogs: false,
      handleExternalNavigation: false,
      enableZoom: false,
      androidHybridComposition: true,
    );
    expect(changed.textScale, TextScaleStrategy.none);
    expect(changed.passTheme, false);
    expect(changed.passA11yPrefs, false);
    expect(changed.passLang, false);
    expect(changed.langOverride, 'en');
    expect(changed.titleFromWeb, false);
    expect(changed.arrival, ArrivalAnnounce.sendAnnouncement);
    expect(changed.syncBackWithWeb, false);
    expect(changed.accessibleLoadingAndError, false);
    expect(changed.handleJsDialogs, false);
    expect(changed.handleExternalNavigation, false);
    expect(changed.enableZoom, false);
    expect(changed.androidHybridComposition, true);

    final same = b.copyWith();
    expect(same.textScale, b.textScale);
    expect(same.arrival, b.arrival);
    expect(same.androidHybridComposition, isNull);
  });
}
