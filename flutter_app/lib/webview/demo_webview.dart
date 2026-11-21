// DemoWebView：所有修正都打開的參考包裝（設計文件 §5、§5.2 基準原則）。
//
// 目前接上的部分：
// - JavaScript 開啟。
// - 頂層網址分成「已換上」與「載入中」、A11yBridge 的信任範圍、ready 握手與設定的傳送、reportReady 補送、
//   字級的責任歸屬（§6.1–§6.3）。這些決策都在 DemoWebViewLogic（純 Dart，有單元測試），
//   這裡只把 WebView 的回呼與 App 發起的載入交給它，再照順序執行它回傳的 WebViewEffect。
// - onWebResourceError 只用來結束載入中狀態，不顯示錯誤畫面。
// 其餘旗標（返回、載入與錯誤的畫面、JS 對話框、外部連結、縮放）之後再接；在那之前，這些方面維持外掛的預設行為。
//
// 朗讀（§6.4）：這裡不朗讀任何東西。網頁回報的標題只寫進 DemoWebController.webTitle，
// 由示範頁安靜地更新 AppBar；基準不主動朗讀頁面標題，否則每一頁的焦點移動都會被念兩次。
//
// DemoWebController 的 setter 會同步通知示範頁重建，所以這裡只在 WebView 的回呼和 Bridge 訊息裡改它的狀態，
// 不在 initState、didChangeDependencies、didUpdateWidget 或 build 裡改。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../contract/bridge_message.dart';
import '../contract/web_contract.dart';
import 'demo_web_controller.dart';
import 'demo_webview_config.dart';
import 'demo_webview_logic.dart';
import 'platform_webview.dart';

/// 網頁 → App 的 JS 頻道名稱（約定，一字不改）。
const String kBridgeChannelName = 'A11yBridge';

/// App 的字級倍率：16px 內文放大後的倍率，限制在 0.8–3.0、四捨五入到兩位小數（設計文件 §6.1）。
///
/// Android 14 以上 Flutter 的字級放大不是線性的，這裡取的是 16px 內文的倍率。
double appTextScaleOf(BuildContext context) => normalizeTextScale(MediaQuery.textScalerOf(context).scale(16) / 16);

/// 依 [config] 從目前的 App 狀態組出要傳給網頁的設定。config 關掉的項目是 null（不傳）。
///
/// - `lang`：[DemoWebViewConfig.langOverride]，沒有時用 App 實際的語系（BCP 47）。
/// - `theme`：App 實際顯示的主題（`Theme.of(context).brightness`），不是系統的設定。
/// - `textScale`：只有「網頁負責」策略才傳（§6.1：有帶這個參數代表由網頁負責放大）。
/// - `reduceMotion`：Android 的「移除動畫」（disableAnimations）或 iOS 的「減少動態效果」任一為真。
///   後者從 View 的 accessibilityFeatures 讀，因為這個 Flutter 版本的 MediaQuery 沒有這一項。
WebSettingsSnapshot snapshotOf(BuildContext context, DemoWebViewConfig config) {
  final prefs = config.passA11yPrefs;
  return WebSettingsSnapshot(
    lang: config.passLang ? (config.langOverride ?? Localizations.localeOf(context).toLanguageTag()) : null,
    theme: config.passTheme ? (Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light') : null,
    textScale: config.textScale == TextScaleStrategy.webOwned ? appTextScaleOf(context) : null,
    bold: prefs ? MediaQuery.boldTextOf(context) : null,
    contrast: prefs ? MediaQuery.highContrastOf(context) : null,
    reduceMotion: prefs
        ? MediaQuery.disableAnimationsOf(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion
        : null,
  );
}

/// 示範頁用的 WebView。
///
/// [uri]、[webBase]、[controller]、[hybridComposition] 只在建立時讀一次。網頁載入後設定的改變用
/// `updateSettings` 通知網頁，不重新載入；要換網址、網頁來源、控制器或顯示模式時，呼叫端要換 key 讓它整個重建，
/// 而且每次重建都配一個新的 [DemoWebController]（舊 WebView 晚到的回呼才不會寫進新的狀態）。
class DemoWebView extends StatefulWidget {
  const DemoWebView({
    super.key,
    required this.uri,
    required this.webBase,
    required this.config,
    required this.controller,
    required this.hybridComposition,
  });

  /// 第一次載入的網址（`buildDemoUri` 的結果）。
  final Uri uri;

  /// 自家網頁的 base，用來判斷信任範圍（[isTrustedPage]）。
  final Uri webBase;

  final DemoWebViewConfig config;

  /// 這個 WebView 專用的控制器。
  final DemoWebController controller;

  /// Android 的顯示模式：true 是 Hybrid Composition，false 是 TLHC。
  final bool hybridComposition;

  @override
  State<DemoWebView> createState() => _DemoWebViewState();
}

/// 在 App 自己發起載入（loadRequest、reload）之前先通知 DemoWebView。
///
/// iOS 第一次載入時 onUrlChange 可能比 onPageStarted 早好幾秒，所以 App 發起的載入要在呼叫時就記為載入中
/// （設計文件 §6.3）。DemoWebController 的 reload()、loadUri() 也經過這裡，不必改它的介面。
class _AppLoadTrackingController extends WebViewController {
  _AppLoadTrackingController() : super();

  /// [target] 為 null 表示重新載入目前的頁面。
  Future<void> Function(Uri? target)? beforeAppLoad;

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const <String, String>{},
    Uint8List? body,
  }) async {
    await beforeAppLoad?.call(uri);
    return super.loadRequest(uri, method: method, headers: headers, body: body);
  }

  @override
  Future<void> reload() async {
    await beforeAppLoad?.call(null);
    return super.reload();
  }
}

class _DemoWebViewState extends State<DemoWebView> with WidgetsBindingObserver {
  final _AppLoadTrackingController _webView = _AppLoadTrackingController();

  // 在 initState 固定下來（見 DemoWebView 的說明）。
  late final DemoWebController _web;
  late final Uri _webBase;
  late final bool _hybridComposition;

  /// 第一次 didChangeDependencies 時建立（要讀 MediaQuery 算設定）。
  late final DemoWebViewLogic _logic;

  bool _started = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _web = widget.controller;
    _webBase = widget.webBase;
    _hybridComposition = widget.hybridComposition;
    _webView.beforeAppLoad = _onAppLoad;
    WidgetsBinding.instance.addObserver(this);
    _web.attach(_webView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _logic = DemoWebViewLogic(
        webBase: _webBase,
        textScale: widget.config.textScale,
        snapshot: snapshotOf(context, widget.config),
        appTextScale: appTextScaleOf(context),
      );
      _bestEffort(_start());
    } else {
      _syncSettings();
    }
  }

  @override
  void didUpdateWidget(DemoWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(widget.controller, oldWidget.controller),
      'DemoWebView 的 controller 不能中途更換；換控制器時要同時換 key，讓 WebView 整個重建。',
    );
    _syncSettings();
  }

  @override
  void didChangeAccessibilityFeatures() {
    // 「減少動態效果」讀的是 View 的 accessibilityFeatures。它改變時 MediaQuery 不一定會通知
    // （這個 Flutter 版本的 MediaQueryData 沒有這一項），所以另外聽。
    if (mounted) _syncSettings();
  }

  @override
  void dispose() {
    _disposed = true;
    _webView.beforeAppLoad = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    await _webView.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webView.setNavigationDelegate(NavigationDelegate(
      onPageStarted: _onPageStarted,
      onPageFinished: _onPageFinished,
      onUrlChange: _onUrlChange,
      onWebResourceError: _onWebResourceError,
    ));
    await _webView.addJavaScriptChannel(kBridgeChannelName, onMessageReceived: _onBridgeMessage);
    if (_disposed) return;
    // 經過 _onAppLoad：先記為載入中並套用 Android 的字級，再載入，第一次畫面才不會被放大兩次。
    await _webView.loadRequest(widget.uri);
  }

  // ── WebView 的回呼與 App 發起的載入 ───────────────────────────────

  Future<void> _onAppLoad(Uri? target) async {
    if (_disposed) return;
    await _apply(_logic.appLoadStarted(target));
  }

  void _onPageStarted(String url) {
    if (_disposed) return;
    _bestEffort(_apply(_logic.pageStarted(url)));
    _web.loading = true;
  }

  void _onUrlChange(UrlChange change) {
    if (_disposed) return;
    _bestEffort(_apply(_logic.urlChanged(change.url)));
  }

  void _onPageFinished(String url) {
    if (_disposed) return;
    _bestEffort(_apply(_logic.pageFinished(url)));
    _web.loading = false;
  }

  void _onWebResourceError(WebResourceError error) {
    if (_disposed) return;
    // 只處理主框架的錯誤；平台沒有提供這個資訊（null）時當成主框架。這個任務只用它結束載入中，不顯示錯誤畫面。
    if (!(error.isForMainFrame ?? true)) return;
    _bestEffort(_apply(_logic.mainFrameError()));
    _web.loading = false;
  }

  void _onBridgeMessage(JavaScriptMessage raw) {
    if (_disposed) return;
    // §6.3 信任範圍：頻道會注入到頁面裡所有的 frame（包括 iframe），只在目前屬於自家網頁時才處理（判斷見 DemoWebViewLogic）。
    if (!_logic.acceptsMessages) return;
    final message = BridgeMessage.parse(raw.message);
    if (message == null) return;
    switch (message) {
      case ReadyMessage(:final title, :final contract, :final caps):
        _web.webTitle = title;
        _web.webContract = contract;
        _web.webCaps = caps;
        _bestEffort(_apply(_logic.readyAccepted()));
      case RouteChangedMessage(:final title):
        _web.webTitle = title;
      default:
        break;
    }
    _web.addMessage(message);
  }

  // ── 設定與字級 ────────────────────────────────────────────────────

  /// MediaQuery、主題、語系或輔助設定改變後，把新的設定與字級交給決策；有變才通知網頁或重新套用字級。
  void _syncSettings() {
    if (!_started || _disposed) return;
    _bestEffort(_apply(_logic.settingsChanged(snapshotOf(context, widget.config), appTextScaleOf(context))));
  }

  /// 照順序執行決策回傳的效果。每一項都是盡力而為：網頁換頁中或 WebView 已經關閉時，原生端可能拒絕，
  /// 失敗只記錄下來，不影響後面的項目，也不變成未處理的例外。
  Future<void> _apply(List<WebViewEffect> effects) async {
    for (final effect in effects) {
      try {
        switch (effect) {
          case SetAndroidTextZoom(:final percent):
            await applyAndroidTextZoom(_webView, percent);
          case SetIosTextSizeAdjust(:final percent):
            await applyIosTextSizeAdjust(_webView, percent);
          case ClearIosTextSizeAdjust():
            await clearIosTextSizeAdjust(_webView);
          case SendSettings(:final snapshot):
            await _webView.runJavaScript(updateSettingsScript(snapshot));
          case RequestReportReady():
            await _webView.runJavaScript(jsCall('reportReady'));
        }
      } catch (error) {
        debugPrint('DemoWebView：$effect 失敗：$error');
      }
    }
  }

  void _bestEffort(Future<void> future) {
    unawaited(future.catchError((Object error) {
      debugPrint('DemoWebView：$error');
    }));
  }

  @override
  Widget build(BuildContext context) => buildPlatformWebViewWidget(_webView, hybridComposition: _hybridComposition);
}
