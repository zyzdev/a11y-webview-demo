// 示範頁（設計文件 §5.3、§5.4）：持有目前的變體與選項，組網址、建立 DemoWebView，接上 AppBar 的按鈕。
// 畫面的骨架由 DemoScaffold 負責。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../catalog/demo_spec.dart';
import '../contract/web_contract.dart';
import '../settings/settings_page.dart';
import '../webview/demo_web_controller.dart';
import '../webview/demo_webview.dart';
import '../webview/demo_webview_config.dart';
import 'demo_scaffold.dart';

/// `titleFromWeb` 為 false 時 AppBar 固定顯示的標題。
const String kFixedDemoTitle = 'WebView 範例';

/// 用 In-app browser 開不了時的提示。
const String kInAppBrowserFailureMessage = '無法用 In-app browser 開啟。內建網頁可能無法從瀏覽器存取，請到設定改用外部網頁來源。';

/// 用 In-app browser（Android 的 Custom Tabs、iOS 的 SFSafariViewController）開啟 [uri]。
///
/// `launchUrl` 回傳 false 或丟例外時顯示 SnackBar。iOS 上使用者在網頁載入完成前就關掉瀏覽器時，
/// url_launcher 也回傳 false，這時同樣會顯示提示。
Future<void> openInAppBrowser(BuildContext context, Uri uri) async {
  // 先取得 ScaffoldMessenger：await 之後這個 context 可能已經不在畫面上。
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (error) {
    debugPrint('openInAppBrowser：$error');
  }
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(content: Text(kInAppBrowserFailureMessage)));
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, required this.spec});

  final DemoSpec spec;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

/// 決定一個 WebView 的四項。任何一項改變就換一個新的 DemoWebController，並用新的 key 重建 WebView。
///
/// 變體、選項：網頁參數和 config 由它們決定（設計文件 §5.3：切換變體時 WebView 整個重建，
/// Android 的字級和顯示模式都是在建立時決定的）。顯示模式：建立後不能改。網頁來源：信任範圍跟著它變。
@immutable
class _WebViewIdentity {
  const _WebViewIdentity({
    required this.variantId,
    required this.options,
    required this.hybridComposition,
    required this.webBase,
  });

  final String variantId;
  final Map<String, String> options;
  final bool hybridComposition;
  final Uri webBase;

  @override
  bool operator ==(Object other) =>
      other is _WebViewIdentity &&
      other.variantId == variantId &&
      mapEquals(other.options, options) &&
      other.hybridComposition == hybridComposition &&
      other.webBase == webBase;

  @override
  int get hashCode => Object.hash(
        variantId,
        Object.hashAllUnordered(options.entries.map((e) => Object.hash(e.key, e.value))),
        hybridComposition,
        webBase,
      );

  @override
  String toString() => 'WebView($variantId, $options, hybrid: $hybridComposition, $webBase)';
}

class _DemoPageState extends State<DemoPage> {
  late DemoVariant _variant;

  /// 每個選項目前的值。一開始就填成各選項的第一個值，同一份 Map 同時交給 DemoScaffold（顯示）和
  /// `configFor`（實際傳給網頁），兩邊才不會不一致。
  late Map<String, String> _options;

  _WebViewIdentity? _identity;

  /// 目前這個 WebView 專用的控制器。每次換 WebView 都換一個新的：控制器沒有重設狀態的方法，
  /// 上一個變體的標題、返回狀態、載入狀態不能留到新的變體。
  DemoWebController? _web;

  @override
  void initState() {
    super.initState();
    _variant = widget.spec.variants.first;
    _options = {
      for (final option in widget.spec.options)
        if (option.choices.isNotEmpty) option.id: option.choices.first,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 設定（顯示模式、網頁來源）改變時 AppScope 會通知到這裡。
    _syncWebView();
  }

  @override
  void dispose() {
    _web?.dispose();
    super.dispose();
  }

  DemoWebViewConfig get _config => widget.spec.configFor(_variant.id, _options);

  /// 目前的變體、選項與設定對應的 WebView；和現在的不同時，換一個新的控制器。
  ///
  /// 只在 didChangeDependencies 和 setState 的回呼裡呼叫，不在 build 裡呼叫。
  void _syncWebView() {
    final scope = AppScope.of(context);
    final identity = _WebViewIdentity(
      variantId: _variant.id,
      options: Map.unmodifiable(_options),
      hybridComposition: _config.androidHybridComposition ?? scope.settings.androidHybridComposition,
      webBase: scope.webBase,
    );
    if (identity == _identity) return;
    _identity = identity;
    // 舊的 WebView 在這一幀結束時才被移除，這段時間（以及之後）它晚到的回呼只會寫進舊的控制器。
    // 控制器 dispose 之後仍接受寫入但不再通知，所以舊的回呼不會影響畫面，也不會丟例外。
    _web?.dispose();
    _web = DemoWebController();
  }

  void _selectVariant(String id) {
    final variant = widget.spec.variants.firstWhere((v) => v.id == id);
    setState(() {
      _variant = variant;
      _syncWebView();
    });
  }

  void _selectOption(String optionId, String value) {
    setState(() {
      _options = {..._options, optionId: value};
      _syncWebView();
    });
  }

  /// AppBar 的標題：網頁回報的標題；還沒回報（或回報的是空白）時用目錄的標題；config 不採用網頁標題時用固定文字。
  String _title(DemoWebViewConfig config, DemoWebController web) {
    if (!config.titleFromWeb) return kFixedDemoTitle;
    final webTitle = web.webTitle;
    if (webTitle == null || webTitle.trim().isEmpty) return widget.spec.title;
    return webTitle;
  }

  void _reload(DemoWebController web) {
    web.reload().catchError((Object error) {
      debugPrint('DemoPage 重新載入失敗：$error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final identity = _identity!;
    final web = _web!;
    final config = _config;
    final variant = _variant;

    final webView = DemoWebView(
      key: ValueKey<_WebViewIdentity>(identity),
      // 只在 WebView 建立時用到；之後設定改變由 DemoWebView 用 updateSettings 通知網頁。
      uri: buildDemoUri(
        base: identity.webBase,
        webPath: spec.webPath,
        webMode: variant.webMode,
        webOff: variant.webOff,
        embedded: true,
        settings: snapshotOf(context, config),
      ),
      webBase: identity.webBase,
      config: config,
      controller: web,
      hybridComposition: identity.hybridComposition,
    );

    // In-app browser 開的是同一頁、同一個變體，但不在 App 內，也不帶 App 的設定。
    final browserUri = buildDemoUri(
      base: identity.webBase,
      webPath: spec.webPath,
      webMode: variant.webMode,
      webOff: variant.webOff,
      embedded: false,
    );

    // 只有頁框跟著控制器的狀態重建；webView 是同一個元件實例，標題改變時不會重建 WebView。
    return ListenableBuilder(
      listenable: web,
      builder: (context, _) => DemoScaffold(
        spec: spec,
        variant: variant,
        onVariantChanged: _selectVariant,
        title: _title(config, web),
        // 基準不主動朗讀頁面標題（設計文件 §6.4），AppBar 標題只安靜地更新。
        titleIsLiveRegion: false,
        options: _options,
        onOptionChanged: _selectOption,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: '用 In-app browser 開啟本頁',
            onPressed: () => openInAppBrowser(context, browserUri),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
            onPressed: () => _reload(web),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
          ...?spec.toolbarBuilder?.call(context, web),
        ],
        body: spec.bodyBuilder?.call(context, variant, webView, web) ?? webView,
      ),
    );
  }
}
