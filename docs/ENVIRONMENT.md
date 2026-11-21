# 開發環境紀錄

檢查日期：2026-11-21（實作計畫 Task 0）。這份檔案只記錄「這台開發機上實際查到的狀況」，後續任務會補上新的結果。

## 工具版本

| 項目 | 結果 |
|---|---|
| Flutter | 3.47.5，stable channel（符合計畫下限 3.41.0） |
| Dart | 3.13.4 |
| Xcode | 27.2（Build 27B52） |
| CocoaPods | **未安裝**（`flutter doctor` 提出警告） |
| Android SDK | **找不到**（`flutter doctor` 回報 Android toolchain 不可用） |
| Node.js | v26.10.0（網頁自我測試用 `node web/test/run.mjs`） |
| Python | 3.14.5（外部網頁來源用 `python3 -m http.server`） |
| git | 2.54.0 |
| rsync | macOS 內建的 openrsync（protocol 29） |

## 可用平台

| 平台 | 狀況 | 依據 |
|---|---|---|
| iOS | **可用** | 沒有 CocoaPods，但 Flutter 的 Swift Package Manager 功能已啟用。用一個拋棄式專案加上 `webview_flutter`、`webview_flutter_android`、`webview_flutter_wkwebview`、`url_launcher`、`shared_preferences` 後，`flutter build ios --simulator --debug` 建置成功（專案路徑含空白也成功） |
| Android | **不可用，未驗證** | 這台機器沒有 Android SDK，無法建置 APK，也沒有 Android 模擬器 |

## 模擬器與裝置

- iOS 模擬器（iOS 27.0）：iPhone 18 Pro、iPhone 18 Pro Max、iPhone 17e、iPhone Air、iPhone 17；另有數台 iPad 模擬器。
- `flutter emulators` 回報「Unable to find any emulator sources」，但 `xcrun simctl list devices available` 列得出上述裝置。啟動方式：`xcrun simctl boot "iPhone 17"` 之後用 `flutter devices` 取得裝置代號，再 `flutter run -d <代號>`。
- 實機：檢查當下有一台已連線的 iPad（iOS 18.7.10）。
- Android 模擬器與 Android 實機：無法從這台機器安裝（缺 Android SDK）。

## 計畫指定的 API 是否存在（對照安裝的 SDK 與套件原始碼）

| API | 結果 |
|---|---|
| `SemanticsService.sendAnnouncement(view, message, textDirection)` | 存在；`announce` 標示為 3.35 之後棄用 |
| `MediaQuery.supportsAnnounceOf` | 存在 |
| `MediaQuery.reduceMotionOf` | 不存在（和計畫的預期一致，計畫改讀 `AccessibilityFeatures.reduceMotion`，該屬性存在） |
| `FocusSemanticEvent`、`RenderObject.sendSemanticsEvent` | 存在 |
| `PopScope.onPopInvokedWithResult` | 存在 |
| `WebViewController.setOnJavaScriptAlertDialog`／`ConfirmDialog`／`TextInputDialog`、`enableZoom`、`canGoBack` | 存在（webview_flutter 4.14.1） |
| `AndroidWebViewController.setTextZoom`、`AndroidWebViewWidgetCreationParams(displayWithHybridComposition:)` | 存在（webview_flutter_android 4.14.1） |
| `WebKitWebViewController.setAllowsBackForwardNavigationGestures` | 存在（webview_flutter_wkwebview 3.27.2） |
| `LaunchMode.inAppBrowserView`、`LaunchMode.externalApplication` | 存在（url_launcher 6.3.3） |

探測時 `flutter pub add` 解析到的版本：`webview_flutter` 4.14.1、`webview_flutter_android` 4.14.1、`webview_flutter_wkwebview` 3.27.2、`url_launcher` 6.3.3、`shared_preferences` 2.5.6（都等於計畫的下限）。正式專案的版本在 Task 2 建立專案後補在這裡。

範本預設值：iOS 部署目標 15.0（計畫要求 ≥ 13.0）、Android `minSdk` 24（計畫要求 ≥ 24）、Android 範本含 `res/values-night/`。

## 未驗證的項目

- **Android 的一切建置與執行**：APK 建置、`AndroidManifest.xml` 與 `network_security_config.xml` 是否正確、TLHC／Hybrid Composition 切換、`setTextZoom`。這些只有 Dart 程式碼經過 `flutter analyze` 與單元測試，原生設定沒有經過建置驗證。
- **所有報讀器行為**（TalkBack 與 VoiceOver）：沒有任何一項在實機上驗證過。iOS 模擬器不能執行 VoiceOver。
- iOS 實機上載入 `http://127.0.0.1`（ATS 設定）與 In-app browser 能否開啟內建網頁：待 Task 5 的實機檢查點確認。
