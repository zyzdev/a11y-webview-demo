// 所有示範頁的宣告。後續任務逐步加入；結構規則由 test/catalog/demo_catalog_test.dart 檢查。
//
// 每一頁的問題版只用 copyWith 關掉該頁自己要示範的那一項，其他維持基準（設計文件 §5.2 基準原則）。
// 可信度、修正方、平台照設計文件 §4；「怎麼測」的內容依設計文件 §7。

import '../webview/demo_webview_config.dart';
import 'demo_spec.dart';

final List<DemoSpec> demoCatalog = <DemoSpec>[
  c01TextScale,
];

/// C01 字體大小（設計文件 §7 C01、§6.1 字級的責任歸屬）。
final DemoSpec c01TextScale = DemoSpec(
  id: 'c01',
  title: '字體大小',
  category: DemoCategory.contract,
  fixSide: FixSide.both,
  confidence: Confidence.verified,
  webPath: 'pages/c01-text-scale.html',
  variants: const [
    DemoVariant('problem', '問題版', webMode: 'problem'),
    DemoVariant('fixed', '修正版', webMode: 'fixed'),
    // 只改 App：網頁維持問題版的寫法，由 App 負責放大。
    DemoVariant('app-only', '只改 App', webMode: 'problem'),
  ],
  configFor: (variantId, options) => switch (variantId) {
        'problem' => DemoWebViewConfig.baseline.copyWith(textScale: TextScaleStrategy.none),
        'app-only' => DemoWebViewConfig.baseline.copyWith(textScale: TextScaleStrategy.appOwned),
        _ => DemoWebViewConfig.baseline,
      },
  howToTest: const HowToTest(
    setup: '先把系統字級調大：Android 在系統設定的「字型大小」，iOS 在「設定 → 輔助使用 → 顯示與文字大小 → 放大文字」。'
        '切換變體會重建 WebView，所以「頁面開著時改字級」要在同一個變體裡做完再切換。',
    steps: [
      '把系統字級調到最大，然後進入這一頁。',
      '依序切換「問題版」「修正版」「只改 App」，每個變體都看「最新消息」三張卡片的字有沒有變大、最後一行有沒有被切掉。',
      '選「修正版」，頁面開著時切到系統設定把字級改小（或改大），再回到 App，看網頁的字有沒有跟著變。',
      '「問題版」和「只改 App」也各做一次步驟 3。',
    ],
    expectProblem: '問題版：iOS 上網頁的字不會變大。Android 上字會變大（WebView 建立時自動套用系統字級），'
        '但卡片高度固定，文字被切掉；頁面開著時改系統字級，網頁不會更新。',
    expectFixed: '修正版：兩個平台的字都跟著系統字級變大，卡片不破版；頁面開著時改系統字級，網頁也會跟著更新。'
        '只改 App：字會變大（Android 用 setTextZoom，iOS 注入 -webkit-text-size-adjust），但卡片仍然破版，'
        '說明網頁還是得配合；頁面開著時改系統字級，網頁也會跟著更新（App 重新套用放大倍率）；'
        '在 iPad 上 -webkit-text-size-adjust 可能無效，需實機確認。',
    evidence: [
      'Chromium AwSettings.java：Android WebView 建立時套用系統字級，之後不再追蹤；呼叫 setTextZoom 就取代這個自動行為。',
      'WebKit bug 187013：WKWebView 預設不跟隨 iOS 的動態字級。',
      '設計文件 §6.1「字級的責任歸屬」：兩邊都放大會重複放大，所以「網頁負責」時 Android 要 setTextZoom(100)。',
    ],
    codeRefs: [
      'web/pages/c01-text-scale.html（問題版與修正版的樣式）',
      'web/shared/a11y-app.js（rootFontPercent：根字級跟著 textScale）',
      'flutter_app/lib/webview/demo_webview.dart（snapshotOf）',
      'flutter_app/lib/webview/demo_webview_logic.dart（textScaleActionFor：字級套用到哪一頁、什麼時候套用）',
      'flutter_app/lib/webview/platform_webview.dart（applyAndroidTextZoom、applyIosTextSizeAdjust、clearIosTextSizeAdjust）',
      'flutter_app/lib/webview/demo_webview_config.dart（TextScaleStrategy、effectiveTextScaleStrategy）',
    ],
  ),
);
