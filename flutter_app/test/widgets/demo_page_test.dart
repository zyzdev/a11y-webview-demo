// DemoPage：變體與選項的狀態、每次換 WebView 都配新的控制器、AppBar 的標題與按鈕、In-app browser。
// WebView 和 url_launcher 都換成假的平台實作；真的網頁與報讀器行為要在模擬器和實機上看。

import 'package:a11y_webview_demo/app.dart';
import 'package:a11y_webview_demo/catalog/demo_catalog.dart';
import 'package:a11y_webview_demo/catalog/demo_spec.dart';
import 'package:a11y_webview_demo/contract/web_contract.dart';
import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:a11y_webview_demo/settings/settings_page.dart';
import 'package:a11y_webview_demo/webview/demo_web_controller.dart';
import 'package:a11y_webview_demo/webview/demo_webview.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:a11y_webview_demo/widgets/demo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../webview/fake_webview_platform.dart';

final _builtInBase = Uri.parse('http://127.0.0.1:8123/');

String _ready(String title) => '{"type":"ready","title":"$title","lang":"zh-TW","contract":1,"caps":["textScale"]}';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher(this.respond);

  final Future<bool> Function() respond;
  final List<(String, PreferredLaunchMode)> launches = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    launches.add((url, options.mode));
    return respond();
  }
}

const _howTo = HowToTest(setup: '前置', steps: ['步驟'], expectProblem: '問題', expectFixed: '修正');

void main() {
  late FakeWebViewPlatform platform;
  late AppSettings settings;

  setUp(() async {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    settings = await AppSettings.load(await SharedPreferences.getInstance());
  });

  Future<void> pumpPage(WidgetTester tester, DemoSpec spec) async {
    await tester.pumpWidget(AppScope(
      settings: settings,
      server: LocalWebServer(loader: (_) async => null),
      builtInBase: _builtInBase,
      child: MaterialApp(home: DemoPage(spec: spec)),
    ));
    await tester.pump();
  }

  String appBarTitle(WidgetTester tester) {
    final title = find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first;
    return tester.widget<Text>(title).data!;
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  group('C01', () {
    testWidgets('載入的網址：內建網頁、embedded=1、依變體的 mode 與 config 帶設定', (tester) async {
      await pumpPage(tester, c01TextScale);
      final context = tester.element(find.byType(DemoWebView));
      final problemConfig = c01TextScale.configFor('problem', const {});
      final expected = buildDemoUri(
        base: _builtInBase,
        webPath: 'pages/c01-text-scale.html',
        webMode: 'problem',
        embedded: true,
        settings: snapshotOf(context, problemConfig),
      );
      expect(platform.last.loadedUris, [expected]);
      expect(expected.query, startsWith('mode=problem&embedded=1&'));
      expect(expected.query, isNot(contains('textScale')), reason: '問題版不做字級');
    });

    testWidgets('AppBar 標題：網頁還沒回報時用目錄的標題，回報後換成網頁的標題，而且不是 liveRegion', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, c01TextScale);
      expect(appBarTitle(tester), '字體大小');

      final c = platform.last;
      c.pageStarted(c.loadedUris.single.toString());
      c.postMessage(_ready('字體大小示範'));
      await tester.pump();
      expect(appBarTitle(tester), '字體大小示範');
      // 基準不主動朗讀頁面標題（§6.4）。
      expect(
        tester.getSemantics(find.descendant(of: find.byType(AppBar), matching: find.text('字體大小示範'))),
        isSemantics(isLiveRegion: false),
      );
      handle.dispose();
    });

    testWidgets('網頁回報空白標題時仍用目錄的標題', (tester) async {
      await pumpPage(tester, c01TextScale);
      final c = platform.last;
      c.pageStarted(c.loadedUris.single.toString());
      c.postMessage(_ready('  '));
      await tester.pump();
      expect(appBarTitle(tester), '字體大小');
    });

    testWidgets('切換變體：重建 WebView、配新的控制器、載入新變體的網址；標題不殘留；舊 WebView 晚到的回呼不影響新的狀態',
        (tester) async {
      await pumpPage(tester, c01TextScale);
      final first = platform.last;
      final firstWeb = tester.widget<DemoWebView>(find.byType(DemoWebView)).controller;
      first.pageStarted(first.loadedUris.single.toString());
      first.postMessage(_ready('問題版的標題'));
      await tester.pump();
      expect(appBarTitle(tester), '問題版的標題');
      expect(firstWeb.loading, isTrue);

      await tester.tap(chip('修正版'));
      await tester.pump();
      await tester.pump();

      expect(platform.controllers, hasLength(2));
      final second = platform.last;
      final secondWeb = tester.widget<DemoWebView>(find.byType(DemoWebView)).controller;
      expect(identical(secondWeb, firstWeb), isFalse);
      expect(second.loadedUris.single.query, startsWith('mode=fixed&embedded=1&'));
      expect(second.loadedUris.single.query, contains('textScale=1.00'));
      expect(appBarTitle(tester), '字體大小', reason: '上一個變體的標題不能留下來');
      expect(secondWeb.webTitle, isNull);
      expect(secondWeb.loading, isFalse);

      // 舊 WebView 晚到的回呼與訊息。
      first.pageStarted(first.loadedUris.single.toString());
      first.postMessage(_ready('晚到的舊標題'));
      first.pageFinished(first.loadedUris.single.toString());
      await tester.pump();
      expect(appBarTitle(tester), '字體大小');
      expect(secondWeb.webTitle, isNull);
      expect(secondWeb.loading, isFalse);
      expect(tester.takeException(), isNull);

      second.pageStarted(second.loadedUris.single.toString());
      second.postMessage(_ready('修正版的標題'));
      await tester.pump();
      expect(appBarTitle(tester), '修正版的標題');

      // 再切到「只改 App」：網頁維持問題版，App 不傳 textScale。
      await tester.tap(chip('只改 App'));
      await tester.pump();
      await tester.pump();
      expect(platform.controllers, hasLength(3));
      expect(platform.last.loadedUris.single.query, startsWith('mode=problem&embedded=1&'));
      expect(platform.last.loadedUris.single.query, isNot(contains('textScale')));
      expect(appBarTitle(tester), '字體大小');
    });

    testWidgets('點目前的變體不重建 WebView', (tester) async {
      await pumpPage(tester, c01TextScale);
      await tester.tap(chip('問題版'));
      await tester.pump();
      expect(platform.controllers, hasLength(1));
    });
  });

  testWidgets('AppBar 按鈕依序是「用 In-app browser 開啟本頁」「重新載入」「設定」，再接 toolbarBuilder 的按鈕', (tester) async {
    DemoWebController? toolbarWeb;
    final spec = DemoSpec(
      id: 'a01',
      title: '假頁',
      category: DemoCategory.appOnly,
      fixSide: FixSide.app,
      confidence: Confidence.verified,
      webPath: 'pages/b-content.html',
      howToTest: _howTo,
      configFor: (_, _) => DemoWebViewConfig.baseline,
      toolbarBuilder: (context, web) {
        toolbarWeb = web;
        return [IconButton(icon: const Icon(Icons.timer), tooltip: '額外按鈕', onPressed: () {})];
      },
    );
    await pumpPage(tester, spec);
    final tooltips = tester
        .widgetList<IconButton>(find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)))
        .map((b) => b.tooltip)
        .toList();
    expect(tooltips, ['用 In-app browser 開啟本頁', '重新載入', '設定', '額外按鈕']);
    expect(toolbarWeb, same(tester.widget<DemoWebView>(find.byType(DemoWebView)).controller));
  });

  testWidgets('「重新載入」重新載入目前的 WebView', (tester) async {
    await pumpPage(tester, c01TextScale);
    await tester.tap(find.byTooltip('重新載入'));
    await tester.pump();
    expect(platform.last.reloadCount, 1);
  });

  testWidgets('「設定」開設定頁', (tester) async {
    await pumpPage(tester, c01TextScale);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  group('用 In-app browser 開啟本頁', () {
    late UrlLauncherPlatform originalLauncher;
    setUp(() => originalLauncher = UrlLauncherPlatform.instance);
    tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

    testWidgets('開的是同一個變體、embedded: false 且不帶設定參數的網址；開得了時不顯示提示', (tester) async {
      final launcher = _FakeUrlLauncher(() async => true);
      UrlLauncherPlatform.instance = launcher;
      await pumpPage(tester, c01TextScale);
      await tester.tap(chip('修正版'));
      await tester.pump();

      await tester.tap(find.byTooltip('用 In-app browser 開啟本頁'));
      await tester.pump();
      final expected = buildDemoUri(
        base: _builtInBase,
        webPath: 'pages/c01-text-scale.html',
        webMode: 'fixed',
        embedded: false,
      );
      expect(expected.toString(), 'http://127.0.0.1:8123/pages/c01-text-scale.html?mode=fixed');
      expect(launcher.launches, [(expected.toString(), PreferredLaunchMode.inAppBrowserView)]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('launchUrl 回傳 false → 顯示 SnackBar', (tester) async {
      UrlLauncherPlatform.instance = _FakeUrlLauncher(() async => false);
      await pumpPage(tester, c01TextScale);
      await tester.tap(find.byTooltip('用 In-app browser 開啟本頁'));
      await tester.pump();
      await tester.pump();
      expect(find.text('無法用 In-app browser 開啟。內建網頁可能無法從瀏覽器存取，請到設定改用外部網頁來源。'), findsOneWidget);
    });

    testWidgets('launchUrl 丟例外 → 顯示 SnackBar，不讓例外漏出去', (tester) async {
      UrlLauncherPlatform.instance = _FakeUrlLauncher(() async => throw PlatformException(code: 'Error'));
      await pumpPage(tester, c01TextScale);
      await tester.tap(find.byTooltip('用 In-app browser 開啟本頁'));
      await tester.pump();
      await tester.pump();
      expect(find.text('無法用 In-app browser 開啟。內建網頁可能無法從瀏覽器存取，請到設定改用外部網頁來源。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('選項', () {
    late List<Map<String, String>> configCalls;
    late DemoSpec spec;

    setUp(() {
      configCalls = [];
      spec = DemoSpec(
        id: 'c04',
        title: '語系',
        category: DemoCategory.contract,
        fixSide: FixSide.both,
        confidence: Confidence.needsDeviceTest,
        webPath: 'pages/b-content.html',
        howToTest: _howTo,
        options: const [DemoOption('lang', 'App 語系（模擬）', ['zh-TW', 'en'])],
        configFor: (variantId, options) {
          configCalls.add(Map.of(options));
          return DemoWebViewConfig.baseline.copyWith(langOverride: options['lang']);
        },
      );
    });

    testWidgets('一開始就填成第一個值，同一份交給 configFor 和下拉選單；改選項時重建 WebView', (tester) async {
      await pumpPage(tester, spec);
      expect(configCalls, isNotEmpty);
      expect(configCalls.every((o) => o['lang'] == 'zh-TW'), isTrue);
      expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value, 'zh-TW');
      expect(platform.last.loadedUris.single.query, contains('lang=zh-TW'));

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('en').last);
      await tester.pumpAndSettle();

      expect(platform.controllers, hasLength(2));
      expect(configCalls.last, {'lang': 'en'});
      expect(platform.last.loadedUris.single.query, contains('lang=en'));
      expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value, 'en');
    });
  });

  testWidgets('titleFromWeb 為 false 時固定顯示「WebView 範例」，網頁送 ready 也不變', (tester) async {
    final spec = DemoSpec(
      id: 'c05',
      title: '標題與重複導覽',
      category: DemoCategory.contract,
      fixSide: FixSide.both,
      confidence: Confidence.verified,
      webPath: 'pages/b-content.html',
      howToTest: _howTo,
      configFor: (_, _) => DemoWebViewConfig.baseline.copyWith(titleFromWeb: false),
    );
    await pumpPage(tester, spec);
    expect(appBarTitle(tester), 'WebView 範例');
    final c = platform.last;
    c.pageStarted(c.loadedUris.single.toString());
    c.postMessage(_ready('網頁的標題'));
    await tester.pump();
    expect(appBarTitle(tester), 'WebView 範例');
  });

  testWidgets('顯示模式或網頁來源改變時重建 WebView、配新的控制器；其他設定改變不重建', (tester) async {
    await pumpPage(tester, c01TextScale);
    expect(tester.widget<DemoWebView>(find.byType(DemoWebView)).hybridComposition, isFalse);

    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(platform.controllers, hasLength(1), reason: '主題改變用 updateSettings 通知，不重建');

    await settings.setAndroidHybridComposition(true);
    await tester.pump();
    await tester.pump();
    expect(platform.controllers, hasLength(2));
    expect(tester.widget<DemoWebView>(find.byType(DemoWebView)).hybridComposition, isTrue);

    await settings.setExternalBaseUrl('http://10.0.2.2:8000/');
    await settings.setWebSource(WebSource.external);
    await tester.pump();
    await tester.pump();
    expect(platform.controllers, hasLength(3));
    expect(platform.last.loadedUris.single.toString(), startsWith('http://10.0.2.2:8000/pages/c01-text-scale.html?'));
    expect(tester.widget<DemoWebView>(find.byType(DemoWebView)).webBase.toString(), 'http://10.0.2.2:8000/');
  });

  testWidgets('bodyBuilder 收到目前的變體、WebView 和控制器', (tester) async {
    DemoVariant? seenVariant;
    DemoWebController? seenWeb;
    final spec = DemoSpec(
      id: 'c10',
      title: '原生按鈕送出網頁表單',
      category: DemoCategory.contract,
      fixSide: FixSide.either,
      confidence: Confidence.needsDeviceTest,
      webPath: 'pages/b-content.html',
      howToTest: _howTo,
      configFor: (_, _) => DemoWebViewConfig.baseline,
      bodyBuilder: (context, variant, webView, web) {
        seenVariant = variant;
        seenWeb = web;
        return Column(children: [Expanded(child: webView), const Text('BODY')]);
      },
    );
    await pumpPage(tester, spec);
    expect(find.text('BODY'), findsOneWidget);
    expect(find.byType(DemoWebView), findsOneWidget);
    expect(seenVariant?.id, 'problem');
    expect(seenWeb, same(tester.widget<DemoWebView>(find.byType(DemoWebView)).controller));
  });
}
