import 'package:a11y_webview_demo/contract/bridge_message.dart';
import 'package:a11y_webview_demo/webview/demo_web_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// 測試用的假控制器：記錄收到的 JS 字串（Task 9–10 的測試也會這樣用）。
class _RecordingController extends DemoWebController {
  final List<String> scripts = [];

  @override
  Future<void> runJavaScript(String js) async => scripts.add(js);
}

void main() {
  test('預設狀態', () {
    final web = DemoWebController();
    expect(web.webTitle, isNull);
    expect(web.webContract, 0);
    expect(web.webCaps, isEmpty);
    expect(web.loading, false);
    expect(web.mainFrameFailed, false);
    expect(web.failureDescription, isNull);
    expect(web.webWantsBack, false);
    expect(web.webCanGoBack, false);
    web.dispose();
  });

  test('狀態欄位改變時通知；值相同不通知', () {
    final web = DemoWebController();
    var count = 0;
    web.addListener(() => count++);
    web.webTitle = '字體大小';
    expect(count, 1);
    web.webTitle = '字體大小';
    expect(count, 1);
    web.loading = true;
    web.webWantsBack = true;
    web.webCaps = const ['textScale'];
    expect(count, 4);
    web.dispose();
  });

  test('dispose 之後改狀態、送訊息都不丟例外（晚到的 WebView 回呼）', () {
    final web = DemoWebController();
    web.dispose();
    web.loading = true;
    web.webTitle = '晚到';
    web.webCaps = const ['textScale'];
    web.addMessage(const CloseMessage());
    expect(web.loading, true);
    expect(web.webTitle, '晚到');
  });

  test('addMessage 送進 messages', () async {
    final web = DemoWebController();
    final received = <BridgeMessage>[];
    final sub = web.messages.listen(received.add);
    web.addMessage(const CloseMessage());
    await Future<void>.delayed(Duration.zero);
    expect(received.single, isA<CloseMessage>());
    await sub.cancel();
    web.dispose();
  });

  test('未 attach 時 runJavaScript、reload、loadUri、goBack 不做事', () async {
    final web = DemoWebController();
    await web.runJavaScript('1');
    await web.reload();
    await web.loadUri(Uri.parse('http://127.0.0.1/'));
    await web.goBack();
    web.dispose();
  });

  test('可以繼承並覆寫 runJavaScript', () async {
    final web = _RecordingController();
    await web.runJavaScript('window.a11yApp&&window.a11yApp.submitForm();');
    expect(web.scripts, ['window.a11yApp&&window.a11yApp.submitForm();']);
    web.dispose();
  });
}
