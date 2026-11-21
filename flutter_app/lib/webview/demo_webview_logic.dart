// DemoWebView 的決策（設計文件 §6.1–§6.3）。純 Dart，不依賴 Flutter，可以直接單元測試。
//
// DemoWebView 只負責把 WebView 的回呼（頁面開始／完成載入、網址改變、主框架錯誤）、App 自己發起的載入、
// 通過信任判斷的 ready 與設定改變交給這裡，再照順序執行這裡回傳的 WebViewEffect。
//
// 頂層網址分成「已換上」與「載入中」兩個（§6.3）。原因是兩個平台回報的時間點不同：
// - iOS 在開始載入新頁面（provisional navigation）時就回報新網址（onPageStarted、onUrlChange），
//   這時畫面上仍是舊頁面，舊頁面仍可能送訊息；換上前被取消時，會先把網址變回原本的再送錯誤回呼；
//   換上後才被停止（window.stop()）時，網址不會變回去。第一次 loadRequest 時 onUrlChange 可能比
//   onPageStarted 早好幾秒。
// - Android 的 onPageStarted 在新頁面換上時才觸發。
// 所以：onPageStarted、App 自己發起的載入都只記為載入中；onPageFinished 才算換上，但只限這次載入有
// onPageStarted 的情況（Android 導向回 204 的網址或取消導覽時，只送一次 onPageFinished，畫面仍是原本的頁面）；
// 主框架錯誤結束載入中，以 WebView 最後回報的網址（載入中的網址）作為已換上的網址；沒有載入中時的 onUrlChange
// 直接更新已換上的網址，但 scheme、host 或埠不同時（網頁內換頁不可能改變這三者）視為開始載入。
// 沒有 onPageStarted 的 onPageFinished 結束載入中時，也以 WebView 最後回報的網址為準：這次載入中收到過
// onUrlChange 就以最後一次 onUrlChange 的網址作為已換上的網址，沒有收到過就維持原本的（onPageFinished 本身帶的
// 網址不採用，Android 導向 204 時它帶的是 204 的網址）。
// iOS 不回報「換上」的時間點：換上後還有資源沒載完（例如很慢的圖片）的頁面在這裡仍是載入中，它再導向別處時，
// 畫面上其實是它。所以載入中又開始新的載入時，先前的載入中網址也列入信任判斷，直到這一串載入結束。

import '../contract/web_contract.dart';
import 'demo_webview_config.dart';

/// 某個字級策略在兩個平台上分別要做的事（設計文件 §6.1 的表）。
class TextScaleAction {
  const TextScaleAction({this.androidTextZoom, this.iosTextSizeAdjust, this.clearIosTextSizeAdjust = false});

  /// Android `setTextZoom` 的百分比；null 表示不動。
  final int? androidTextZoom;

  /// iOS 注入到已換上那一頁的 `-webkit-text-size-adjust` 百分比；null 表示不注入。
  final int? iosTextSizeAdjust;

  /// iOS 清掉已換上那一頁的 `-webkit-text-size-adjust`（設成空字串）。
  final bool clearIosTextSizeAdjust;

  @override
  bool operator ==(Object other) =>
      other is TextScaleAction &&
      other.androidTextZoom == androidTextZoom &&
      other.iosTextSizeAdjust == iosTextSizeAdjust &&
      other.clearIosTextSizeAdjust == clearIosTextSizeAdjust;

  @override
  int get hashCode => Object.hash(androidTextZoom, iosTextSizeAdjust, clearIosTextSizeAdjust);

  @override
  String toString() =>
      'TextScaleAction(android: $androidTextZoom, ios: $iosTextSizeAdjust, clearIos: $clearIosTextSizeAdjust)';
}

/// 實際採用的策略 [effective]（已經過 [effectiveTextScaleStrategy]）與 App 字級倍率 [appTextScale] 對應的動作。
///
/// - 網頁負責：Android `setTextZoom(100)`，關掉 WebView 建立時自動套用的系統字級，避免和網頁的根字級重複放大；
///   iOS 清掉 `-webkit-text-size-adjust`（WKWebView 本來就不跟系統字級，清掉是保險）。
/// - App 負責：兩個平台都放大到倍率×100。
/// - 都不做：兩個平台都不動，Android 維持 WebView 建立時自動套用的系統字級。
TextScaleAction textScaleActionFor(TextScaleStrategy effective, double appTextScale) {
  final percent = (appTextScale * 100).round();
  return switch (effective) {
    TextScaleStrategy.none => const TextScaleAction(),
    TextScaleStrategy.webOwned => const TextScaleAction(androidTextZoom: 100, clearIosTextSizeAdjust: true),
    TextScaleStrategy.appOwned => TextScaleAction(androidTextZoom: percent, iosTextSizeAdjust: percent),
  };
}

/// DemoWebView 要對 WebView 做的一件事。
sealed class WebViewEffect {
  const WebViewEffect();
}

/// Android：`setTextZoom(percent)`（整個 WebView 的設定）。在 iOS 上 DemoWebView 執行時不做事。
final class SetAndroidTextZoom extends WebViewEffect {
  const SetAndroidTextZoom(this.percent);
  final int percent;

  @override
  bool operator ==(Object other) => other is SetAndroidTextZoom && other.percent == percent;
  @override
  int get hashCode => Object.hash(SetAndroidTextZoom, percent);
  @override
  String toString() => 'SetAndroidTextZoom($percent)';
}

/// iOS：對目前這一份文件注入 `-webkit-text-size-adjust: percent%`。只在沒有載入中時產生，所以目前的文件就是已換上的那一頁。
final class SetIosTextSizeAdjust extends WebViewEffect {
  const SetIosTextSizeAdjust(this.percent);
  final int percent;

  @override
  bool operator ==(Object other) => other is SetIosTextSizeAdjust && other.percent == percent;
  @override
  int get hashCode => Object.hash(SetIosTextSizeAdjust, percent);
  @override
  String toString() => 'SetIosTextSizeAdjust($percent)';
}

/// iOS：清掉目前這一份文件的 `-webkit-text-size-adjust`。只在沒有載入中時產生。
final class ClearIosTextSizeAdjust extends WebViewEffect {
  const ClearIosTextSizeAdjust();

  @override
  bool operator ==(Object other) => other is ClearIosTextSizeAdjust;
  @override
  int get hashCode => (ClearIosTextSizeAdjust).hashCode;
  @override
  String toString() => 'ClearIosTextSizeAdjust()';
}

/// 執行 `updateSettingsScript(snapshot)`。
final class SendSettings extends WebViewEffect {
  const SendSettings(this.snapshot);
  final WebSettingsSnapshot snapshot;

  @override
  bool operator ==(Object other) => other is SendSettings && other.snapshot == snapshot;
  @override
  int get hashCode => Object.hash(SendSettings, snapshot);
  @override
  String toString() => 'SendSettings(textScale: ${snapshot.textScale}, theme: ${snapshot.theme})';
}

/// 執行 `jsCall('reportReady')`，請已換上的自家頁面補送 ready（設計文件 §6.2）。
final class RequestReportReady extends WebViewEffect {
  const RequestReportReady();

  @override
  bool operator ==(Object other) => other is RequestReportReady;
  @override
  int get hashCode => (RequestReportReady).hashCode;
  @override
  String toString() => 'RequestReportReady()';
}

/// 一個 WebView 的頂層網址、信任判斷、ready 狀態、設定與字級的決策。每個 WebView 一個。
class DemoWebViewLogic {
  DemoWebViewLogic({
    required this.webBase,
    required this.textScale,
    required this._snapshot,
    required this._appTextScale,
  });

  /// 自家網頁的 base（信任範圍）。
  final Uri webBase;

  /// config 指定的字級策略（還沒依網址調整）。
  final TextScaleStrategy textScale;

  Uri? _committed;
  Uri? _pending;
  bool _loading = false;

  /// 這次載入收到 onPageStarted 了沒。沒有的話 onPageFinished 不算換上（見 [pageFinished]）。
  bool _pageStartedThisLoad = false;

  /// 這次載入中收到 onUrlChange 了沒（包括開始這次載入的那一次）。收到過的話 [_pending] 就是最後一次
  /// onUrlChange 回報的網址。
  bool _urlChangedThisLoad = false;

  /// 從上一次載入結束之後，這一串載入中出現過的每一個載入中網址（新的載入、onUrlChange，包括目前的）是不是都
  /// 屬於自家網域。沒有載入中時開始的載入是新的一串，從 true 算起；載入中又開始新的載入時接著算，不重設。
  bool _pendingChainTrusted = true;

  /// 已換上的那一頁送過 ready（而且被接受）了沒。換上新頁時才更新，不在開始載入時重設。
  bool _readyOnCommitted = false;

  /// 這次載入中收到（而且被接受）的 ready。換上時交給 [_readyOnCommitted]。
  bool _readyDuringLoad = false;

  WebSettingsSnapshot _snapshot;

  /// 最近一次送給已換上那一頁的設定。null 表示這一頁還沒送過。
  WebSettingsSnapshot? _sentSnapshot;

  double _appTextScale;

  /// 最近一次 Android setTextZoom 的值。它是整個 WebView 的設定，同樣的值不重送。
  int? _appliedAndroidTextZoom;

  /// 已換上、正在畫面上的那一頁。還沒換上過任何頁面時是 null。
  Uri? get committedUrl => _committed;

  /// 載入中的網址（WebView 最後回報的網址）。沒有載入中時是 null。
  Uri? get pendingUrl => _pending;

  bool get loading => _loading;

  bool get readyOnCommittedPage => _readyOnCommitted;

  bool _isTrusted(Uri? uri) => isTrustedPage(uri, webBase);

  /// 目前收到的 Bridge 訊息要不要處理（§6.3 信任範圍）。
  ///
  /// 沒有載入中：看已換上的網址。載入中：已換上的網址，以及這一串載入中出現過的每一個載入中網址（包括目前的）
  /// 都要屬於自家網域，因為 iOS 換上前畫面上是舊頁面、換上後是新頁面，App 分不出訊息是哪一頁送的；而換上後
  /// 仍在載入中的頁面再導向別處時，畫面上是它，它的網址只留在先前的載入中網址裡。還沒換上過任何頁面時不看
  /// 已換上的網址。
  bool get acceptsMessages {
    if (!_loading) return _isTrusted(_committed);
    if (!_pendingChainTrusted) return false;
    return _committed == null || _isTrusted(_committed);
  }

  // ── 事件 ───────────────────────────────────────────────────────────

  /// App 自己發起的載入（第一次 loadRequest、reload、loadUri）。[target] 為 null 表示重新載入目前已換上的那一頁。
  List<WebViewEffect> appLoadStarted(Uri? target) {
    _startLoad(target ?? _committed);
    return _androidTextZoom();
  }

  /// WebView 的 onPageStarted。只記為載入中。
  List<WebViewEffect> pageStarted(String url) {
    _startLoad(_parse(url));
    _pageStartedThisLoad = true;
    return _androidTextZoom();
  }

  /// WebView 的 onUrlChange。
  List<WebViewEffect> urlChanged(String? url) {
    final uri = _parse(url);
    if (_loading) {
      // 轉址，或 iOS 取消載入時把網址變回原本的。
      _pending = uri;
      _pendingChainTrusted = _pendingChainTrusted && _isTrusted(uri);
      _urlChangedThisLoad = true;
      return _androidTextZoom();
    }
    final committed = _committed;
    if (committed == null || uri == null || !_sameOrigin(uri, committed)) {
      // 網頁內換頁不可能改變 scheme、host、埠，所以這一定是跨文件的載入，只是 onPageStarted 還沒到。
      _startLoad(uri);
      _urlChangedThisLoad = true;
      return _androidTextZoom();
    }
    // 網頁內換頁（pushState、錨點）：同一份文件，ready 狀態不變。
    final wasTrusted = _isTrusted(committed);
    _committed = uri;
    return [
      ..._androidTextZoom(),
      if (_isTrusted(uri) != wasTrusted) ..._iosTextSizeForCommitted(),
    ];
  }

  /// WebView 的 onPageFinished：這一頁換上了（只限這次載入有 onPageStarted）。
  List<WebViewEffect> pageFinished(String url) {
    if (!_pageStartedThisLoad) {
      // 這次載入沒有 onPageStarted：Android 導向回 204 的網址、取消導覽時只送一次 onPageFinished，畫面仍是原本的
      // 頁面。onPageFinished 本身帶的網址不採用（204 時它是 204 的網址）。
      if (!_loading) return const [];
      // 這次載入中收到過 onUrlChange（例如換了 origin 的 onUrlChange 開始的載入）：和主框架錯誤同一個原則，
      // 以 WebView 最後回報的網址為準。
      if (_urlChangedThisLoad) return _settleOnLastReportedUrl();
      // 沒有收到過（App 發起、還沒收到 onPageStarted 的載入）：只結束載入中，已換上的網址不變，不請網頁補送
      // ready、不重算字級（Android 的 setTextZoom 在沒有 onPageStarted 的載入中本來就沒有改，見
      // [_androidTextZoom]）。載入中被擋下的設定改變照常補送給原本那一頁。
      _loading = false;
      _urlChangedThisLoad = false;
      _pending = null;
      // 沒有新文件換上，這段期間被接受的 ready 只可能來自原本那一頁。
      _readyOnCommitted = _readyOnCommitted || _readyDuringLoad;
      _readyDuringLoad = false;
      return _flushSettings();
    }
    final uri = _parse(url) ?? _pending ?? _committed;
    if (!_loading && uri == _committed) {
      // 同一份文件重複回報完成（例如 Android 錯誤頁在錯誤回呼之後才回報完成），狀態已經是最新的。
      return const [];
    }
    _commit(uri, readyDuringLoad: _readyDuringLoad);
    return [..._androidTextZoom(), ..._iosTextSizeForCommitted(), ..._afterCommit()];
  }

  /// WebView 的主框架錯誤（載入失敗或取消）。結束載入中，以 WebView 最後回報的網址作為已換上的網址。
  List<WebViewEffect> mainFrameError() {
    if (!_loading) return const [];
    return _settleOnLastReportedUrl();
  }

  /// 收到通過信任判斷的 ready。送那一頁目前的設定。
  List<WebViewEffect> readyAccepted() {
    if (_loading) {
      _readyDuringLoad = true;
    } else {
      _readyOnCommitted = true;
    }
    _sentSnapshot = _snapshot;
    return [SendSettings(_snapshot)];
  }

  /// MediaQuery、主題、語系或輔助設定改變後的設定與 App 字級倍率。
  List<WebViewEffect> settingsChanged(WebSettingsSnapshot snapshot, double appTextScale) {
    final effects = <WebViewEffect>[];
    if (appTextScale != _appTextScale) {
      _appTextScale = appTextScale;
      effects.addAll(_androidTextZoom());
      // iOS 的注入只作用在單一份文件；載入中不注入，等載入完成時再依新的倍率注入。
      if (!_loading && _effectiveFor(_committed) == TextScaleStrategy.appOwned) {
        effects.addAll(_iosTextSizeForCommitted());
      }
    }
    _snapshot = snapshot;
    effects.addAll(_flushSettings());
    return effects;
  }

  // ── 內部 ───────────────────────────────────────────────────────────

  void _startLoad(Uri? uri) {
    // 沒有載入中時開始的是新的一串；載入中又開始新的載入時，先前的載入中網址繼續列入判斷。
    _pendingChainTrusted = (!_loading || _pendingChainTrusted) && _isTrusted(uri);
    _loading = true;
    _pending = uri;
    _readyDuringLoad = false;
    _pageStartedThisLoad = false;
    _urlChangedThisLoad = false;
  }

  /// 結束載入中，以 WebView 最後回報的網址（載入中的網址）作為已換上的網址。呼叫端保證正在載入中。
  /// 用在主框架錯誤，以及這次載入中收到過 onUrlChange、但沒有 onPageStarted 的 onPageFinished。
  List<WebViewEffect> _settleOnLastReportedUrl() {
    final last = _pending;
    if (last == _committed) {
      // 換上前就失敗或被取消：網址已經變回原本的那一頁，它的 ready 狀態不變。
      _loading = false;
      _pending = null;
      _readyDuringLoad = false;
      _pageStartedThisLoad = false;
      _urlChangedThisLoad = false;
      return [..._androidTextZoom(), ..._flushSettings()];
    }
    // 網址沒有變回去：畫面上是新頁面（例如換上後被 window.stop() 停止）。
    _commit(last, readyDuringLoad: _readyDuringLoad);
    return [..._androidTextZoom(), ..._iosTextSizeForCommitted(), ..._afterCommit()];
  }

  void _commit(Uri? uri, {required bool readyDuringLoad}) {
    _committed = uri;
    _pending = null;
    _loading = false;
    _pageStartedThisLoad = false;
    _urlChangedThisLoad = false;
    _readyOnCommitted = readyDuringLoad;
    _readyDuringLoad = false;
    if (!_readyOnCommitted) _sentSnapshot = null;
  }

  /// 換上新頁之後：自家頁面還沒送過 ready 就請它補送；送過就補上載入中錯過的設定改變。
  List<WebViewEffect> _afterCommit() {
    if (!_isTrusted(_committed)) return const [];
    if (!_readyOnCommitted) return const [RequestReportReady()];
    return _flushSettings();
  }

  /// 設定只送給已換上、屬於自家網域、而且送過 ready 的頁面，內容和上次送的不同時才送。
  List<WebViewEffect> _flushSettings() {
    if (_loading || !_isTrusted(_committed) || !_readyOnCommitted) return const [];
    if (_snapshot == _sentSnapshot) return const [];
    _sentSnapshot = _snapshot;
    return [SendSettings(_snapshot)];
  }

  TextScaleStrategy _effectiveFor(Uri? uri) => effectiveTextScaleStrategy(textScale, trustedPage: _isTrusted(uri));

  /// Android 的 setTextZoom 跟著畫面上的文件走：Android 在 onPageStarted 時已換上新頁面，所以這次載入收到
  /// onPageStarted 之後用載入中的網址；還沒收到（App 發起的載入、onUrlChange 開始的載入）時畫面仍是已換上的那一頁。
  /// 例外是第一次載入：還沒有已換上的頁面，先依要載入的網址設定，第一次畫面才不會被放大兩次。
  /// （iOS 上 DemoWebView 執行這個效果時不做事。）
  List<WebViewEffect> _androidTextZoom() {
    final onScreen = _loading && (_pageStartedThisLoad || _committed == null) ? _pending : _committed;
    final zoom = textScaleActionFor(_effectiveFor(onScreen), _appTextScale).androidTextZoom;
    if (zoom == null || zoom == _appliedAndroidTextZoom) return const [];
    _appliedAndroidTextZoom = zoom;
    return [SetAndroidTextZoom(zoom)];
  }

  /// iOS 對已換上那一頁要做的事。呼叫端保證沒有載入中。
  List<WebViewEffect> _iosTextSizeForCommitted() {
    final action = textScaleActionFor(_effectiveFor(_committed), _appTextScale);
    final adjust = action.iosTextSizeAdjust;
    if (adjust != null) return [SetIosTextSizeAdjust(adjust)];
    if (action.clearIosTextSizeAdjust) return const [ClearIosTextSizeAdjust()];
    return const [];
  }

  static Uri? _parse(String? url) => (url == null || url.isEmpty) ? null : Uri.tryParse(url);

  static bool _sameOrigin(Uri a, Uri b) => a.scheme == b.scheme && a.host == b.host && a.port == b.port;
}
