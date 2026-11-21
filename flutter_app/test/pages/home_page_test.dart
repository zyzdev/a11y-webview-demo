import 'package:a11y_webview_demo/app.dart';
import 'package:a11y_webview_demo/catalog/demo_spec.dart';
import 'package:a11y_webview_demo/pages/home_page.dart';
import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:a11y_webview_demo/settings/settings_page.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DemoWebViewConfig _baseline(String variantId, Map<String, String> options) => DemoWebViewConfig.baseline;

const _howTo = HowToTest(setup: '前置', steps: ['步驟'], expectProblem: '問題', expectFixed: '修正');

const _specs = [
  DemoSpec(
    id: 'c01',
    title: '字體大小',
    category: DemoCategory.contract,
    fixSide: FixSide.both,
    confidence: Confidence.verified,
    webPath: 'pages/b-content.html',
    howToTest: _howTo,
    configFor: _baseline,
  ),
  DemoSpec(
    id: 'b01',
    title: '疊在 WebView 上方的 Flutter 元件點不到',
    category: DemoCategory.boundary,
    fixSide: FixSide.none,
    confidence: Confidence.needsDeviceTest,
    webPath: 'pages/b-content.html',
    howToTest: _howTo,
    configFor: _baseline,
    platform: DemoPlatform.android,
  ),
];

Widget _page({List<DemoSpec> specs = _specs}) =>
    MaterialApp(home: HomePage(specs: specs, pageBuilder: (spec) => const Text('PAGE')));

void main() {
  testWidgets('有資料的分區顯示標題且帶 header 語意；沒有資料的分區不顯示', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_page());
    expect(find.text('兩邊約定'), findsOneWidget);
    expect(find.text('交界處限制'), findsOneWidget);
    expect(tester.getSemantics(find.text('兩邊約定')), isSemantics(isHeader: true));
    expect(tester.getSemantics(find.text('交界處限制')), isSemantics(isHeader: true));
    expect(find.text('App 單方處理'), findsNothing);
    expect(find.text('工具'), findsNothing);
    handle.dispose();
  });

  testWidgets('每列顯示大寫代號與標題，以及修正方、可信度、平台', (tester) async {
    await tester.pumpWidget(_page());
    expect(find.text('C01'), findsOneWidget);
    expect(find.text('字體大小'), findsOneWidget);
    expect(find.text('B01'), findsOneWidget);
    expect(find.text('疊在 WebView 上方的 Flutter 元件點不到'), findsOneWidget);
    expect(find.text('修正在：兩邊 · 已查證 · 兩個平台'), findsOneWidget);
    expect(find.text('需實機確認 · 只有 Android'), findsOneWidget);
  });

  testWidgets('點一列後畫面出現 PAGE', (tester) async {
    await tester.pumpWidget(_page());
    await tester.tap(find.text('字體大小'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE'), findsOneWidget);
  });

  testWidgets('目錄是空的時不顯示任何分區', (tester) async {
    await tester.pumpWidget(_page(specs: const []));
    for (final name in ['兩邊約定', 'App 單方處理', '交界處限制', '工具']) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('AppBar 有「設定」按鈕，點了開設定頁', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppScope(
      settings: settings,
      server: LocalWebServer(loader: (_) async => null),
      builtInBase: Uri.parse('http://127.0.0.1:1234/'),
      child: _page(),
    ));
    expect(find.byTooltip('設定'), findsOneWidget);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
