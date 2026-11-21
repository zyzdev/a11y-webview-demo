// DemoWebView 的邏輯：信任範圍、ready 握手與設定的傳送、載入狀態、dispose 後晚到的回呼、字級策略的對應。
// WebView 換成假的平台實作（fake_webview_platform.dart），所以只測得到「DemoWebView 對 WebView 下了什麼指令」，
// 測不到網頁實際的樣子和報讀器行為。

import 'package:a11y_webview_demo/contract/bridge_message.dart';
import 'package:a11y_webview_demo/contract/web_contract.dart';
import 'package:a11y_webview_demo/webview/demo_web_controller.dart';
import 'package:a11y_webview_demo/webview/demo_webview.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview_platform.dart';

final _base = Uri.parse('http://127.0.0.1:8123/');
final _page = Uri.parse('http://127.0.0.1:8123/pages/c01-text-scale.html?mode=fixed&embedded=1');
const _ready = '{"type":"ready","title":"字體大小示範","lang":"zh-TW","contract":1,"caps":["textScale"]}';

Widget _host(DemoWebController web, {DemoWebViewConfig config = DemoWebViewConfig.baseline, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: DemoWebView(uri: _page, webBase: _base, config: config, controller: web, hybridComposition: false),
    );

/// 目前畫面上的 DemoWebView 依 [config] 算出的設定。
WebSettingsSnapshot _snapshotNow(WidgetTester tester, [DemoWebViewConfig config = DemoWebViewConfig.baseline]) =>
    snapshotOf(tester.element(find.byType(DemoWebView)), config);

void main() {
  late FakeWebViewPlatform platform;
  late DemoWebController web;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    web = DemoWebController();
  });

  tearDown(() => web.dispose());

  testWidgets('建立時：JavaScript 開啟、註冊 A11yBridge 頻道、載入 uri；這時還不送設定', (tester) async {
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    expect(platform.controllers, hasLength(1));
    expect(c.javaScriptMode, JavaScriptMode.unrestricted);
    expect(c.channels.keys, ['A11yBridge']);
    expect(c.loadedUris, [_page]);
    expect(c.settingsScripts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onPageStarted／onPageFinished 更新 loading', (tester) async {
    await tester.pumpWidget(_host(web));
    await tester.pump();
    platform.last.pageStarted(_page.toString());
    expect(web.loading, isTrue);
    platform.last.pageFinished(_page.toString());
    expect(web.loading, isFalse);
  });

  testWidgets('自家網頁送 ready：更新 webTitle、webContract、webCaps，送進 messages，並送一次 updateSettings', (tester) async {
    final received = <BridgeMessage>[];
    final sub = web.messages.listen(received.add);
    addTearDown(sub.cancel);
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());
    c.postMessage(_ready);
    await tester.pump();

    expect(web.webTitle, '字體大小示範');
    expect(web.webContract, 1);
    expect(web.webCaps, ['textScale']);
    expect(received.single, isA<ReadyMessage>());
    expect(c.settingsScripts, [updateSettingsScript(_snapshotNow(tester))]);
  });

  testWidgets('routeChanged 更新 webTitle，也送進 messages', (tester) async {
    final received = <BridgeMessage>[];
    final sub = web.messages.listen(received.add);
    addTearDown(sub.cancel);
    await tester.pumpWidget(_host(web));
    await tester.pump();
    platform.last.pageStarted(_page.toString());
    platform.last.postMessage('{"type":"routeChanged","title":"詳情","path":"/pages/x.html"}');
    await tester.pump();
    expect(web.webTitle, '詳情');
    expect(received.single, isA<RouteChangedMessage>());
  });

  testWidgets('目前頂層網址不是自家網頁時，訊息一律忽略（§6.3 信任範圍）', (tester) async {
    final received = <BridgeMessage>[];
    final sub = web.messages.listen(received.add);
    addTearDown(sub.cancel);
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;

    for (final url in ['https://example.com/', 'http://127.0.0.1:9999/pages/c01-text-scale.html', 'about:blank']) {
      c.pageStarted(url);
      c.postMessage(_ready);
    }
    // 網頁內換頁（不觸發 onPageStarted）到其他網域也一樣。
    c.pageStarted(_page.toString());
    c.urlChanged('https://example.com/elsewhere');
    c.postMessage(_ready);
    await tester.pump();

    expect(web.webTitle, isNull);
    expect(web.webContract, 0);
    expect(received, isEmpty);
    expect(c.settingsScripts, isEmpty);
  });

  testWidgets('無法解析或不認得的訊息忽略，不丟例外', (tester) async {
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());
    for (final raw in ['', 'not json', '[]', '{"type":"unknown"}', '{"type":"ready"}']) {
      c.postMessage(raw);
    }
    await tester.pump();
    expect(web.webTitle, isNull);
    expect(c.settingsScripts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('字級改變：ready 之前不送；ready 之後送新的設定；值沒變不重送；換頁後要等下一次 ready', (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pump();
    expect(c.settingsScripts, isEmpty, reason: '網頁還沒送 ready');

    c.postMessage(_ready);
    c.pageFinished(_page.toString());
    await tester.pump();
    expect(_snapshotNow(tester).textScale, 1.5);
    expect(c.settingsScripts, [updateSettingsScript(_snapshotNow(tester))]);

    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pump();
    expect(c.settingsScripts, hasLength(2));
    expect(c.settingsScripts.last, updateSettingsScript(_snapshotNow(tester)));
    expect(c.settingsScripts.last, contains('"textScale":2.0'));

    await tester.pump();
    expect(c.settingsScripts, hasLength(2), reason: '設定沒變就不重送');

    // 換頁：新的一頁送 ready 之前不送，送了之後送目前的設定。
    c.pageStarted('http://127.0.0.1:8123/index.html');
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pump();
    expect(c.settingsScripts, hasLength(2));
    c.postMessage(_ready);
    await tester.pump();
    expect(c.settingsScripts, hasLength(3));
    expect(c.settingsScripts.last, contains('"textScale":1.3'));
  });

  testWidgets('App 主題改變時再送一次設定', (tester) async {
    await tester.pumpWidget(_host(web, theme: ThemeData(brightness: Brightness.light)));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());
    c.postMessage(_ready);
    c.pageFinished(_page.toString());
    await tester.pump();
    expect(c.settingsScripts.single, contains('"theme":"light"'));

    await tester.pumpWidget(_host(web, theme: ThemeData(brightness: Brightness.dark)));
    await tester.pumpAndSettle();
    expect(c.settingsScripts, hasLength(2));
    expect(c.settingsScripts.last, contains('"theme":"dark"'));
  });

  testWidgets('只有平台的「減少動態效果」改變（MediaQuery 沒變）時也會再送', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());
    c.postMessage(_ready);
    c.pageFinished(_page.toString());
    await tester.pump();
    expect(c.settingsScripts.single, contains('"reduceMotion":false'));

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(c.settingsScripts, hasLength(2));
    expect(c.settingsScripts.last, contains('"reduceMotion":true'));
  });

  testWidgets('config 關掉 textScale 時，設定裡沒有 textScale', (tester) async {
    final config = DemoWebViewConfig.baseline.copyWith(textScale: TextScaleStrategy.none);
    await tester.pumpWidget(_host(web, config: config));
    await tester.pump();
    final c = platform.last;
    c.pageStarted(_page.toString());
    c.postMessage(_ready);
    await tester.pump();
    expect(c.settingsScripts.single, isNot(contains('textScale')));
  });

  testWidgets('dispose 之後晚到的回呼與訊息：不寫進控制器、不送 JS、不丟例外', (tester) async {
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    await tester.pumpWidget(const SizedBox());

    c.pageStarted(_page.toString());
    c.urlChanged(_page.toString());
    c.postMessage(_ready);
    c.pageFinished(_page.toString());
    await tester.pump();

    expect(web.loading, isFalse);
    expect(web.webTitle, isNull);
    expect(c.scripts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // ── 已換上／載入中（設計文件 §6.3），用 iOS 的回呼時序 ──────────────────

  /// 第一次載入自家頁面並換上。
  Future<FakeWebViewController> loadSelf(WidgetTester tester) async {
    await tester.pumpWidget(_host(web));
    await tester.pump();
    final c = platform.last;
    c.urlChanged(_page.toString()); // iOS：第一次載入時 onUrlChange 先到
    c.pageStarted(_page.toString());
    c.postMessage(_ready);
    c.pageFinished(_page.toString());
    await tester.pump();
    expect(web.webTitle, '字體大小示範');
    return c;
  }

  const ext = 'http://127.0.0.1:8766/evil.html';
  const selfSlow = 'http://127.0.0.1:8123/pages/c01-text-scale.html?mode=fixed&embedded=1&__delay=7000';
  const fakeReady = '{"type":"ready","title":"假標題","lang":"zh-TW","contract":1,"caps":[]}';

  testWidgets('iOS 時序：外部頁在自家頁載入中送的假 ready 一律被擋，標題不變；載入完成後請網頁補送 reportReady', (tester) async {
    final c = await loadSelf(tester);
    c.pageStarted(ext);
    c.urlChanged(ext);
    c.pageFinished(ext);
    await tester.pump();
    final scriptsBefore = c.scripts.length;

    // 外部頁導向自家慢速頁：iOS 在 onPageStarted／onUrlChange 時就回報自家網址，但畫面上還是外部頁。
    c.pageStarted(selfSlow);
    c.urlChanged(selfSlow);
    for (var i = 0; i < 24; i++) {
      c.postMessage(fakeReady);
    }
    await tester.pump();
    expect(web.webTitle, '字體大小示範', reason: '假 ready 不能改掉標題');
    expect(c.scripts.length, scriptsBefore, reason: '假 ready 不能觸發 updateSettings');

    c.pageFinished(selfSlow);
    await tester.pump();
    expect(c.scripts.last, jsCall('reportReady'));

    c.postMessage(_ready);
    await tester.pump();
    expect(c.settingsScripts.last, updateSettingsScript(_snapshotNow(tester)));
  });

  testWidgets('自家頁導向 204：載入中自家頁的訊息被擋；變回原網址並收到錯誤後恢復接受、loading 回到 false、改字級仍送設定',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await loadSelf(tester);
    const route = '{"type":"routeChanged","title":"自家頁送的標題","path":"/pages/c01-text-scale.html"}';

    c.pageStarted('http://127.0.0.1:8766/nocontent');
    c.urlChanged('http://127.0.0.1:8766/nocontent');
    expect(web.loading, isTrue);
    c.postMessage(route);
    await tester.pump();
    expect(web.webTitle, '字體大小示範', reason: '載入中兩個網址都要屬於自家');

    c.urlChanged(_page.toString()); // 變回原網址
    c.webResourceError(errorCode: 102); // 頁框載入中斷
    await tester.pump();
    expect(web.loading, isFalse);
    c.postMessage(route);
    await tester.pump();
    expect(web.webTitle, '自家頁送的標題');

    final before = c.settingsScripts.length;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pump();
    expect(c.settingsScripts.length, before + 1);
    expect(c.settingsScripts.last, contains('"textScale":1.5'));
  });

  testWidgets('Android 導向 204：只收到 onPageFinished，畫面仍是自家頁 → 自家頁的訊息照常接受、不補送', (tester) async {
    final c = await loadSelf(tester);
    final scriptsBefore = c.scripts.length;
    c.pageFinished('http://127.0.0.1:8766/nocontent');
    c.postMessage('{"type":"routeChanged","title":"204後自家","path":"/pages/c01-text-scale.html"}');
    await tester.pump();
    expect(web.webTitle, '204後自家');
    expect(web.loading, isFalse);
    expect(c.scripts.length, scriptsBefore, reason: '不送 reportReady');
  });

  testWidgets('App 發起的 loadUri 打到 204（只收到 onPageFinished）：結束載入中、原本的頁面恢復被接受', (tester) async {
    final c = await loadSelf(tester);
    await web.loadUri(Uri.parse('http://127.0.0.1:8766/nocontent'));
    c.pageFinished('http://127.0.0.1:8766/nocontent');
    c.postMessage('{"type":"routeChanged","title":"仍是自家頁","path":"/pages/c01-text-scale.html"}');
    await tester.pump();
    expect(web.webTitle, '仍是自家頁');
    expect(c.scripts, isNot(contains(jsCall('reportReady'))));
  });

  testWidgets('window.stop()：外部頁換上後只有錯誤回呼、網址沒變回去 → 外部頁的訊息被擋', (tester) async {
    final c = await loadSelf(tester);
    c.pageStarted(ext);
    c.urlChanged(ext);
    c.webResourceError(errorCode: -999);
    c.postMessage('{"type":"routeChanged","title":"停止頁假標題","path":"/x"}');
    await tester.pump();
    expect(web.webTitle, '字體大小示範');
    expect(web.loading, isFalse);
  });

  testWidgets('isForMainFrame 為 false 的錯誤不結束載入中；為 null 時當成主框架', (tester) async {
    final c = await loadSelf(tester);
    c.pageStarted(ext);
    c.urlChanged(_page.toString());
    c.webResourceError(isForMainFrame: false);
    await tester.pump();
    expect(web.loading, isTrue);
    c.webResourceError(isForMainFrame: null);
    await tester.pump();
    expect(web.loading, isFalse);
  });

  testWidgets('App 發起的 loadUri 在呼叫時就記為載入中：外部網址載入中，自家頁的訊息被擋', (tester) async {
    final c = await loadSelf(tester);
    await web.loadUri(Uri.parse(ext));
    await tester.pump();
    expect(c.loadedUris.last, Uri.parse(ext));
    c.postMessage('{"type":"routeChanged","title":"載入中的訊息","path":"/x"}');
    await tester.pump();
    expect(web.webTitle, '字體大小示範');
  });

  testWidgets('App 發起的 reload 記為載入中：重新載入完成時沒收到 ready 就請網頁補送', (tester) async {
    final c = await loadSelf(tester);
    await web.reload();
    expect(c.reloadCount, 1);
    c.pageStarted(_page.toString());
    c.pageFinished(_page.toString());
    await tester.pump();
    expect(c.scripts.last, jsCall('reportReady'));
  });
}
