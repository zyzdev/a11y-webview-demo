// 示範頁和 DemoWebView 之間共用的狀態與操作。本檔只定義狀態與介面，由 DemoWebView（Task 5）驅動。
//
// 不是 final class：測試會繼承它並覆寫 runJavaScript 來記錄收到的 JS 字串。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../contract/bridge_message.dart';

class DemoWebController extends ChangeNotifier {
  // 狀態欄位寫成 getter／setter：值有變才 notifyListeners。
  // notifyListeners 是 @protected，DemoWebView 從外面改狀態時就靠這些 setter 通知示範頁重建。

  String? _webTitle;
  int _webContract = 0;
  List<String> _webCaps = const [];
  bool _loading = false;
  bool _mainFrameFailed = false;
  String? _failureDescription;
  bool _webWantsBack = false;
  bool _webCanGoBack = false;

  /// 網頁在 `ready`／`routeChanged` 回報的標題。尚未回報時為 null。
  String? get webTitle => _webTitle;
  set webTitle(String? v) => _set(_webTitle, v, () => _webTitle = v);

  /// 網頁在 `ready` 回報的約定版本。0 表示沒有回報。
  int get webContract => _webContract;
  set webContract(int v) => _set(_webContract, v, () => _webContract = v);

  /// 網頁在 `ready` 回報的、這一頁目前啟用的修正名稱。
  List<String> get webCaps => _webCaps;
  set webCaps(List<String> v) => _set(_webCaps, v, () => _webCaps = v, equal: listEquals(_webCaps, v));

  bool get loading => _loading;
  set loading(bool v) => _set(_loading, v, () => _loading = v);

  /// 目前頂層載入的 http(s) 網址失敗（設計文件 §5.2：只有這種情況才用 Flutter 畫面取代 WebView）。
  bool get mainFrameFailed => _mainFrameFailed;
  set mainFrameFailed(bool v) => _set(_mainFrameFailed, v, () => _mainFrameFailed = v);

  String? get failureDescription => _failureDescription;
  set failureDescription(String? v) => _set(_failureDescription, v, () => _failureDescription = v);

  /// 網頁回報有東西要先關（`backState`）。
  bool get webWantsBack => _webWantsBack;
  set webWantsBack(bool v) => _set(_webWantsBack, v, () => _webWantsBack = v);

  /// WebView 有上一頁。
  bool get webCanGoBack => _webCanGoBack;
  set webCanGoBack(bool v) => _set(_webCanGoBack, v, () => _webCanGoBack = v);

  void _set<T>(T old, T value, void Function() assign, {bool? equal}) {
    if (equal ?? old == value) return;
    assign();
    notifyListeners();
  }

  final StreamController<BridgeMessage> _messages = StreamController<BridgeMessage>.broadcast();

  /// 從網頁收到、而且通過信任檢查與解析的 Bridge 訊息。
  Stream<BridgeMessage> get messages => _messages.stream;

  /// DemoWebView 收到 Bridge 訊息時呼叫；測試也用它送假訊息。
  void addMessage(BridgeMessage m) {
    if (!_messages.isClosed) _messages.add(m);
  }

  WebViewController? _controller;

  /// DemoWebView 建立 WebView 後呼叫。未 attach 時 [runJavaScript]、[reload]、[loadUri]、[goBack] 不做事。
  void attach(WebViewController c) {
    _controller = c;
  }

  Future<void> runJavaScript(String js) async {
    await _controller?.runJavaScript(js);
  }

  Future<void> reload() async {
    await _controller?.reload();
  }

  Future<void> loadUri(Uri uri) async {
    await _controller?.loadRequest(uri);
  }

  Future<void> goBack() async {
    await _controller?.goBack();
  }

  @override
  void dispose() {
    _messages.close();
    _controller = null;
    super.dispose();
  }
}
