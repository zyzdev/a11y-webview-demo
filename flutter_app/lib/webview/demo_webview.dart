// DemoWebView：所有修正都打開的參考包裝（設計文件 §5、§5.2 基準原則）。
//
// 目前接上的部分：
// - JavaScript 開啟；用 onPageStarted／onUrlChange 追蹤目前的頂層網址。
// - A11yBridge 頻道：只有目前頂層網址屬於自家網頁時才處理訊息（§6.3 信任範圍）。
// - 收到 ready 後送一次設定；之後系統設定或 App 主題改變時再送（§6.2）。
// - 字級的責任歸屬（§6.1）。
// 其餘旗標（返回、載入與錯誤、JS 對話框、外部連結、縮放）之後再接；在那之前，這些方面維持外掛的預設行為。
//
// 朗讀（§6.4）：這裡不朗讀任何東西。網頁回報的標題只寫進 DemoWebController.webTitle，
// 由示範頁安靜地更新 AppBar；基準不主動朗讀頁面標題，否則每一頁的焦點移動都會被念兩次。
//
// DemoWebController 的 setter 會同步通知示範頁重建，所以這裡只在 WebView 的回呼和 Bridge 訊息裡改它的狀態，
// 不在 initState、didChangeDependencies、didUpdateWidget 或 build 裡改。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../contract/bridge_message.dart';
import '../contract/web_contract.dart';
import 'demo_web_controller.dart';
import 'demo_webview_config.dart';
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

/// 某個字級策略在兩個平台上分別要做的事（設計文件 §6.1 的表）。null 表示這個平台不做事。
@immutable
class TextScaleAction {
  const TextScaleAction({this.androidTextZoom, this.iosTextSizeAdjust});

  /// Android `setTextZoom` 的百分比。
  final int? androidTextZoom;

  /// iOS 注入的 `-webkit-text-size-adjust` 百分比。
  final int? iosTextSizeAdjust;

  @override
  bool operator ==(Object other) =>
      other is TextScaleAction && other.androidTextZoom == androidTextZoom && other.iosTextSizeAdjust == iosTextSizeAdjust;

  @override
  int get hashCode => Object.hash(androidTextZoom, iosTextSizeAdjust);

  @override
  String toString() => 'TextScaleAction(android: $androidTextZoom, ios: $iosTextSizeAdjust)';
}

/// 實際採用的策略 [effective]（已經過 [effectiveTextScaleStrategy]）與 App 字級倍率 [appTextScale] 對應的動作。
///
/// - 網頁負責：Android `setTextZoom(100)`，關掉 WebView 建立時自動套用的系統字級，避免和網頁的根字級重複放大；
///   iOS 不做事（WKWebView 本來就不跟系統字級）。
/// - App 負責：兩個平台都放大到倍率×100。
/// - 都不做：兩個平台都不動，Android 維持 WebView 建立時自動套用的系統字級。
TextScaleAction textScaleActionFor(TextScaleStrategy effective, double appTextScale) {
  final percent = (appTextScale * 100).round();
  return switch (effective) {
    TextScaleStrategy.none => const TextScaleAction(),
    TextScaleStrategy.webOwned => const TextScaleAction(androidTextZoom: 100),
    TextScaleStrategy.appOwned => TextScaleAction(androidTextZoom: percent, iosTextSizeAdjust: percent),
  };
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

class _DemoWebViewState extends State<DemoWebView> with WidgetsBindingObserver {
  final WebViewController _webView = WebViewController();

  // 在 initState 固定下來（見 DemoWebView 的說明）。
  late final DemoWebController _web;
  late final Uri _webBase;
  late final bool _hybridComposition;

  /// 目前的頂層網址。載入前先當作要載入的網址，第一次的字級策略和信任判斷才有依據。
  Uri? _topUrl;

  /// 這一頁（最近一次 onPageStarted 之後）的網頁送過 ready 了沒。送過之後設定改變才通知網頁。
  bool _readyOnThisPage = false;

  bool _started = false;
  bool _disposed = false;

  /// 最近一次算出的設定與 App 字級倍率。
  late WebSettingsSnapshot _snapshot;
  late double _appTextScale;

  /// 最近一次對 Android 呼叫 setTextZoom 的值。文字縮放是整個 WebView 的設定，換頁後仍然有效，同樣的值不重送。
  int? _appliedAndroidTextZoom;

  @override
  void initState() {
    super.initState();
    _web = widget.controller;
    _webBase = widget.webBase;
    _hybridComposition = widget.hybridComposition;
    _topUrl = widget.uri;
    WidgetsBinding.instance.addObserver(this);
    _web.attach(_webView);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _snapshot = snapshotOf(context, widget.config);
      _appTextScale = appTextScaleOf(context);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    await _webView.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webView.setNavigationDelegate(NavigationDelegate(
      onPageStarted: _onPageStarted,
      onPageFinished: _onPageFinished,
      onUrlChange: _onUrlChange,
    ));
    await _webView.addJavaScriptChannel(kBridgeChannelName, onMessageReceived: _onBridgeMessage);
    // 先套用字級再載入：Android「網頁負責」要先關掉 WebView 自己的放大，第一次畫面才不會被放大兩次。
    await _applyTextScale(injectIos: false);
    if (_disposed) return;
    await _webView.loadRequest(widget.uri);
  }

  // ── WebView 的回呼 ────────────────────────────────────────────────

  void _onPageStarted(String url) {
    if (_disposed) return;
    _readyOnThisPage = false;
    _setTopUrl(url);
    _web.loading = true;
  }

  void _onUrlChange(UrlChange change) {
    if (_disposed) return;
    final url = change.url;
    if (url != null) _setTopUrl(url);
  }

  void _onPageFinished(String url) {
    if (_disposed) return;
    _web.loading = false;
    // iOS 的 -webkit-text-size-adjust 只作用在目前這份文件，載入完成後再注入一次。
    _bestEffort(_applyTextScale(injectIos: true));
  }

  void _setTopUrl(String url) {
    _topUrl = Uri.tryParse(url);
    // 每次頂層網址改變都重算策略：導到其他網域時「網頁負責」改成「App 負責」（§6.1）。
    _bestEffort(_applyTextScale(injectIos: true));
  }

  bool get _onTrustedPage => isTrustedPage(_topUrl, _webBase);

  void _onBridgeMessage(JavaScriptMessage raw) {
    if (_disposed) return;
    // §6.3 信任範圍：頻道會注入到頁面裡所有的 frame（包括 iframe），只在目前頂層網址屬於自家網頁時才處理。
    if (!_onTrustedPage) return;
    final message = BridgeMessage.parse(raw.message);
    if (message == null) return;
    switch (message) {
      case ReadyMessage(:final title, :final contract, :final caps):
        _web.webTitle = title;
        _web.webContract = contract;
        _web.webCaps = caps;
        _readyOnThisPage = true;
        _sendSettings();
      case RouteChangedMessage(:final title):
        _web.webTitle = title;
      default:
        break;
    }
    _web.addMessage(message);
  }

  // ── 設定與字級 ────────────────────────────────────────────────────

  /// MediaQuery、主題、語系或輔助設定改變後，重算設定與字級；有變才通知網頁或重新套用字級。
  void _syncSettings() {
    if (!_started || _disposed) return;
    final scale = appTextScaleOf(context);
    if (scale != _appTextScale) {
      _appTextScale = scale;
      // 「App 負責」的倍率不在 snapshot 裡（textScale 是 null），要另外比較。
      _bestEffort(_applyTextScale(injectIos: true));
    }
    final snapshot = snapshotOf(context, widget.config);
    if (snapshot != _snapshot) {
      _snapshot = snapshot;
      if (_readyOnThisPage && _onTrustedPage) _sendSettings();
    }
  }

  void _sendSettings() {
    _bestEffort(_webView.runJavaScript(updateSettingsScript(_snapshot)));
  }

  /// 依目前的頂層網址與 App 字級倍率套用字級策略。
  ///
  /// [injectIos] 為 false 時不注入 iOS 的 -webkit-text-size-adjust（還沒有文件可以注入）。
  Future<void> _applyTextScale({required bool injectIos}) async {
    final effective = effectiveTextScaleStrategy(widget.config.textScale, trustedPage: _onTrustedPage);
    final action = textScaleActionFor(effective, _appTextScale);
    final zoom = action.androidTextZoom;
    if (zoom != null && zoom != _appliedAndroidTextZoom) {
      _appliedAndroidTextZoom = zoom;
      await applyAndroidTextZoom(_webView, zoom);
    }
    final adjust = action.iosTextSizeAdjust;
    if (injectIos && adjust != null) {
      await applyIosTextSizeAdjust(_webView, adjust);
    }
  }

  /// 對 WebView 的呼叫都是盡力而為：網頁換頁中或 WebView 已經關閉時，原生端可能拒絕。
  /// 失敗只記錄下來，不讓它變成未處理的例外。
  void _bestEffort(Future<void> future) {
    unawaited(future.catchError((Object error) {
      debugPrint('DemoWebView：$error');
    }));
  }

  @override
  Widget build(BuildContext context) => buildPlatformWebViewWidget(_webView, hybridComposition: _hybridComposition);
}
