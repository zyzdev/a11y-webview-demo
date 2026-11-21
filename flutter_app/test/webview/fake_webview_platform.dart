// 測試用的假 WebView 平台：取代 WebViewPlatform.instance，記錄 DemoWebView 對 WebView 做了什麼，
// 也讓測試可以模擬 WebView 的回呼（頁面開始／完成載入、網址改變）和網頁送來的 A11yBridge 訊息。
//
// 只模擬 DemoWebView 用到的部分；它沒有真的網頁，所以字級在畫面上的效果、報讀器行為都測不到。

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  /// 依建立順序記錄每一個 WebView 的控制器。
  final List<FakeWebViewController> controllers = [];

  FakeWebViewController get last => controllers.last;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    final controller = FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      FakeWebViewWidget(params);
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  JavaScriptMode? javaScriptMode;
  FakeNavigationDelegate? delegate;
  final Map<String, JavaScriptChannelParams> channels = {};
  final List<Uri> loadedUris = [];
  final List<String> scripts = [];
  int reloadCount = 0;

  /// 送進 [runJavaScript] 的 updateSettings 呼叫。
  List<String> get settingsScripts => scripts.where((s) => s.contains('updateSettings')).toList();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => this.javaScriptMode = javaScriptMode;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as FakeNavigationDelegate;

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async =>
      channels[javaScriptChannelParams.name] = javaScriptChannelParams;

  @override
  Future<void> loadRequest(LoadRequestParams params) async => loadedUris.add(params.uri);

  @override
  Future<void> runJavaScript(String javaScript) async => scripts.add(javaScript);

  @override
  Future<void> reload() async => reloadCount++;

  // ── 模擬 WebView 的回呼 ──

  void pageStarted(String url) => delegate!.onPageStarted!(url);
  void pageFinished(String url) => delegate!.onPageFinished!(url);
  void urlChanged(String? url) => delegate!.onUrlChange!(UrlChange(url: url));

  /// 模擬網頁呼叫 `A11yBridge.postMessage(message)`。
  void postMessage(String message) => channels['A11yBridge']!.onMessageReceived(JavaScriptMessage(message: message));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async => this.onPageStarted = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async => this.onPageFinished = onPageFinished;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async => this.onUrlChange = onUrlChange;
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key('fake-webview'));
}
