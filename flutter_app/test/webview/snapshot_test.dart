// snapshotOf：從 MediaQuery、主題、語系與 View 的輔助設定組出要傳給網頁的設定（設計文件 §6.1）。

import 'package:a11y_webview_demo/contract/web_contract.dart';
import 'package:a11y_webview_demo/webview/demo_webview.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 在指定的 MediaQuery、深色主題與 zh_TW 語系之下，對每個 config 算出 snapshot。
Future<Map<String, WebSettingsSnapshot>> _snapshots(
  WidgetTester tester, {
  required MediaQueryData data,
  required Map<String, DemoWebViewConfig> configs,
}) async {
  final result = <String, WebSettingsSnapshot>{};
  await tester.pumpWidget(
    Localizations(
      locale: const Locale('zh', 'TW'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: MediaQuery(
        data: data,
        child: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Builder(builder: (context) {
            configs.forEach((name, config) => result[name] = snapshotOf(context, config));
            return const SizedBox();
          }),
        ),
      ),
    ),
  );
  return result;
}

const _data = MediaQueryData(
  textScaler: TextScaler.linear(1.3),
  boldText: true,
  highContrast: true,
  disableAnimations: true,
);

const _baseline = DemoWebViewConfig.baseline;

void main() {
  testWidgets('baseline：所有設定都傳', (tester) async {
    final s = await _snapshots(tester, data: _data, configs: {'baseline': _baseline});
    expect(
      s['baseline'],
      const WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3, bold: true, contrast: true, reduceMotion: true),
    );
  });

  testWidgets('copyWith 關掉某一項，只有那一項變成 null；langOverride 取代 App 的語系', (tester) async {
    final s = await _snapshots(tester, data: _data, configs: {
      'none': _baseline.copyWith(textScale: TextScaleStrategy.none),
      'appOwned': _baseline.copyWith(textScale: TextScaleStrategy.appOwned),
      'noTheme': _baseline.copyWith(passTheme: false),
      'noPrefs': _baseline.copyWith(passA11yPrefs: false),
      'noLang': _baseline.copyWith(passLang: false),
      'en': _baseline.copyWith(langOverride: 'en'),
    });

    expect(s['none']!.textScale, isNull);
    expect(s['appOwned']!.textScale, isNull);
    expect(s['noTheme']!.theme, isNull);
    expect(s['noPrefs']!.bold, isNull);
    expect(s['noPrefs']!.contrast, isNull);
    expect(s['noPrefs']!.reduceMotion, isNull);
    expect(s['noLang']!.lang, isNull);
    expect(s['en']!.lang, 'en');

    // 另外加的斷言：其他欄位維持基準的值（基準原則：只關掉那一項）。
    expect(
      s['none'],
      const WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', bold: true, contrast: true, reduceMotion: true),
    );
    expect(
      s['noPrefs'],
      const WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3),
    );
  });

  testWidgets('textScaler 為 linear(5.0) 時 baseline 的 textScale 為 3.0', (tester) async {
    final s = await _snapshots(
      tester,
      data: _data.copyWith(textScaler: const TextScaler.linear(5.0)),
      configs: {'baseline': _baseline},
    );
    expect(s['baseline']!.textScale, 3.0);
  });

  testWidgets('disableAnimations 為 false，但平台的 reduceMotion 為 true → reduceMotion 為 true', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = await _snapshots(
      tester,
      data: _data.copyWith(disableAnimations: false),
      configs: {'baseline': _baseline},
    );
    expect(s['baseline']!.reduceMotion, isTrue);
  });

  testWidgets('另外加的：兩者都是 false 時 reduceMotion 為 false；淺色主題傳 light', (tester) async {
    final result = <WebSettingsSnapshot>[];
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: GlobalMaterialLocalizations.delegates,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Theme(
            data: ThemeData(brightness: Brightness.light),
            child: Builder(builder: (context) {
              result.add(snapshotOf(context, _baseline));
              return const SizedBox();
            }),
          ),
        ),
      ),
    );
    expect(
      result.last,
      const WebSettingsSnapshot(lang: 'en', theme: 'light', textScale: 1.0, bold: false, contrast: false, reduceMotion: false),
    );
  });
}
