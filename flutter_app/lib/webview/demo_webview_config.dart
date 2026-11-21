// DemoWebView 的設定（設計文件 §5.2 基準原則）。
//
// 預設值就是「基準」：所有修正都打開。每一頁的問題版只用 copyWith 關掉該頁自己要示範的那一項，
// 其他項維持基準，才不會影響別頁問題版的樣子。

/// 字級由誰負責放大（設計文件 §6.1「字級的責任歸屬」）。
enum TextScaleStrategy {
  /// 都不做（C01 問題版）。
  none,

  /// 網頁負責（基準）：App 傳 `textScale`，Android 另外 `setTextZoom(100)` 關掉 WebView 自己的放大。
  webOwned,

  /// App 負責：不傳 `textScale`，Android 用 `setTextZoom`，iOS 注入 `-webkit-text-size-adjust`。
  appOwned,
}

/// 頁面抵達時怎麼告訴報讀器使用者（設計文件 §6.4）。
enum ArrivalAnnounce {
  /// 基準：不主動朗讀，由網頁移動焦點。
  none,

  /// AppBar 標題設成 liveRegion，標題改變時由報讀器念出。
  liveRegionTitle,

  /// 用 `SemanticsService.sendAnnouncement`（只在 iOS 有效）。
  sendAnnouncement,
}

class DemoWebViewConfig {
  const DemoWebViewConfig({
    this.textScale = TextScaleStrategy.webOwned,
    this.passTheme = true,
    this.passA11yPrefs = true,
    this.passLang = true,
    this.langOverride,
    this.titleFromWeb = true,
    this.arrival = ArrivalAnnounce.none,
    this.syncBackWithWeb = true,
    this.accessibleLoadingAndError = true,
    this.handleJsDialogs = true,
    this.handleExternalNavigation = true,
    this.enableZoom = true,
    this.androidHybridComposition,
  });

  /// 基準：所有修正都打開。
  static const baseline = DemoWebViewConfig();

  final TextScaleStrategy textScale;

  /// 傳 `theme`（App 實際顯示的主題）給網頁。
  final bool passTheme;

  /// 傳 `bold`、`contrast`、`reduceMotion` 給網頁。
  final bool passA11yPrefs;

  /// 傳 `lang` 給網頁。
  final bool passLang;

  /// 不是 null 時，傳給網頁的 `lang` 用這個值，而不是 App 的語系。
  final String? langOverride;

  /// AppBar 標題用網頁回報的標題。
  final bool titleFromWeb;

  final ArrivalAnnounce arrival;

  /// 返回鍵先問網頁、再看 WebView 的上一頁，最後才關閉畫面。
  final bool syncBackWithWeb;

  /// 載入中與錯誤用報讀器讀得到的 Flutter 元件顯示。
  final bool accessibleLoadingAndError;

  /// 網頁的 `alert`／`confirm`／`prompt` 由 App 顯示對話框。
  final bool handleJsDialogs;

  /// `tel:`、`mailto:`、外部網域的連結交給系統處理。
  final bool handleExternalNavigation;

  /// 允許使用者縮放網頁。
  final bool enableZoom;

  /// Android 的顯示模式。null = 依 AppSettings。
  final bool? androidHybridComposition;

  /// 每個欄位一個具名參數；沒給的欄位維持原值。
  ///
  /// 可為 null 的欄位（[langOverride]、[androidHybridComposition]）無法用 copyWith 改回 null；
  /// 需要時直接用建構子。
  DemoWebViewConfig copyWith({
    TextScaleStrategy? textScale,
    bool? passTheme,
    bool? passA11yPrefs,
    bool? passLang,
    String? langOverride,
    bool? titleFromWeb,
    ArrivalAnnounce? arrival,
    bool? syncBackWithWeb,
    bool? accessibleLoadingAndError,
    bool? handleJsDialogs,
    bool? handleExternalNavigation,
    bool? enableZoom,
    bool? androidHybridComposition,
  }) {
    return DemoWebViewConfig(
      textScale: textScale ?? this.textScale,
      passTheme: passTheme ?? this.passTheme,
      passA11yPrefs: passA11yPrefs ?? this.passA11yPrefs,
      passLang: passLang ?? this.passLang,
      langOverride: langOverride ?? this.langOverride,
      titleFromWeb: titleFromWeb ?? this.titleFromWeb,
      arrival: arrival ?? this.arrival,
      syncBackWithWeb: syncBackWithWeb ?? this.syncBackWithWeb,
      accessibleLoadingAndError: accessibleLoadingAndError ?? this.accessibleLoadingAndError,
      handleJsDialogs: handleJsDialogs ?? this.handleJsDialogs,
      handleExternalNavigation: handleExternalNavigation ?? this.handleExternalNavigation,
      enableZoom: enableZoom ?? this.enableZoom,
      androidHybridComposition: androidHybridComposition ?? this.androidHybridComposition,
    );
  }
}

/// 實際採用的字級策略。
///
/// 設計文件 §6.1：「網頁負責」只套用在自家網域的頁面。WebView 導到其他網域時，那個頁面沒有實作約定，
/// 若仍維持 `setTextZoom(100)`，大字級使用者看到的字反而變小，所以改用「App 負責」。
TextScaleStrategy effectiveTextScaleStrategy(TextScaleStrategy configured, {required bool trustedPage}) {
  if (configured == TextScaleStrategy.webOwned && !trustedPage) return TextScaleStrategy.appOwned;
  return configured;
}
