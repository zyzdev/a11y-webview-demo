# 開發環境紀錄

檢查日期：2026-11-21。這份文件記錄的是**第二台電腦**（Mac mini，arm64，macOS 27.0.1）的環境，是換電腦後重做實作計畫 Task 0 的結果。Task 0 和 Task 1 是在第一台電腦上做的，那台沒有 Android SDK；第一台的紀錄在這個檔案的 git 歷史裡（`d2ef5d9` 的版本）。

這份檔案只記錄「這台開發機上實際查到的狀況」，後續任務會補上新的結果。

## 工具版本

| 項目 | 結果 |
|---|---|
| Flutter | 3.47.5，stable channel（符合計畫下限 3.41.0）。由 fvm 安裝，位置 `~/fvm/versions/3.47.5` |
| Dart | 3.13.4 |
| Xcode | 27.0（Build 27A266a），iOS SDK 27.0 |
| CocoaPods | 1.16.2 |
| Flutter 的 Swift Package Manager | **關閉**（這台原本的 Flutter 設定 `enable-swift-package-manager: false`）。iOS 外掛走 CocoaPods，和第一台（SPM 啟用、沒有 CocoaPods）不同 |
| Android SDK | `~/Library/Android/sdk`。platform `android-27` 到 `android-36`、build-tools 最高 36.0.0、NDK 22.1／26.3／27.0／28.2、模擬器 37.1.11.0 |
| Android Studio | **沒有安裝** |
| JDK | Amazon Corretto 20.0.2.1（由 Flutter 設定 `jdk-dir` 指定，見下一節）。機器上另有 Corretto 19、11、8 與 OpenJDK 20.0.1；沒有 17 或 21 |
| Android 範本用的建置工具 | Gradle 9.3.1、Android Gradle Plugin 9.1.0、Kotlin 2.4.0，Java 與 Kotlin 的目標版本是 17 |
| Node.js | v22.23.2（網頁自我測試用 `node web/test/run.mjs`） |
| Python | 3.14.5（外部網頁來源用 `python3 -m http.server`） |
| git | 2.54.0 |
| rsync | macOS 內建的 openrsync（protocol 29） |

## 這台電腦的 Flutter 設定改了什麼

接手時 `flutter doctor -v`、`flutter emulators` 都直接當掉，`flutter create --platforms=android,ios` 也以 exit 1 結束。原因是 Flutter 的全域設定 `android-studio-dir` 指向 `/Applications/Android Studio.app`，而這台沒有裝 Android Studio。

使用者在 2026-11-21 同意後做了兩個修改，都只動 Flutter 自己的設定檔（`~/.config/flutter/settings`）：

| 指令 | 作用 |
|---|---|
| `flutter config --android-studio-dir=""` | 清掉失效的路徑。原值是 `/Applications/Android Studio.app` |
| `flutter config --jdk-dir="$HOME/Library/Java/JavaVirtualMachines/corretto-20.0.2.1/Contents/Home"` | 指定 Flutter 用哪個 JDK |

沒有改的東西：

- `~/.zshrc` 的 `JAVA_HOME` 仍然指向不存在的 `/Applications/Android Studio.app/Contents/jbr/Contents/Home`。Flutter 的 `jdk-dir` 優先於 `JAVA_HOME`，所以透過 `flutter` 指令的建置不受影響；直接執行 `./gradlew` 會受影響。
- 沒有安裝或升級任何東西。Android SDK 的內容在探測前後相同。

`flutter doctor -v` 修改後的結果：Flutter、Xcode、Chrome、Connected device、Network resources 都是通過；Android toolchain 有一個警告「Some Android licenses not accepted」。目前的建置不需要下載新的 SDK 元件，所以沒有被這個警告擋到。之後如果 Gradle 要下載 SDK 元件而失敗，要由使用者自己執行 `flutter doctor --android-licenses` 閱讀並接受授權條款。

## 可用平台

兩個平台都用拋棄式專案（放在暫存目錄，不在這個 repo 裡）加上 `webview_flutter`、`webview_flutter_android`、`webview_flutter_wkwebview`、`url_launcher`、`shared_preferences` 實際建置過。

| 平台 | 狀況 | 依據 |
|---|---|---|
| iOS | **可用** | `flutter build ios --simulator --debug` 建置成功（CocoaPods，`pod install` 正常） |
| Android | **可用** | `flutter build apk --debug` 建置成功（修改設定後用真實設定再建一次也成功）。APK 裝進 Android 模擬器後可以啟動，行程存在 |

### Task 5 在模擬器上看到的結果（2026-11-21，debug 建置）

只是模擬器上的畫面和 log，沒有用報讀器，也不代表實機一定一樣。

**iOS（iPhone 17，iOS 27.0）**

- 內建網頁 `http://127.0.0.1:<埠>/pages/c01-text-scale.html` 在 WKWebView 載入成功，沒有被 ATS 擋下。
- Bridge 通了：AppBar 標題從目錄的「字體大小」換成網頁回報的「字體大小示範」。debug log 裡 `onPageStarted` 一律比網頁的 `ready` 先到，信任判斷放行。
- 三個變體都切換得了。每次切換都重新載入，AppBar 標題先回到「字體大小」，等新網頁送 `ready` 後才換成網頁標題。
- 字級：`xcrun simctl ui <udid> content_size extra-extra-extra-large` 可以用，Flutter 得到的倍率是 1.35（做完已改回 `large`）。
  - 問題版：網頁的字不變。
  - 修正版：網頁收到 `textScale` 1.35，根字級 135%，卡片跟著變高、沒有被切掉。頁面開著時改回 `large`，網頁即時變回 100%。
  - 只改 App：注入 `-webkit-text-size-adjust` 後網頁的字變大，但卡片高度固定，最後一行被切掉。頁面開著時改字級，App 會重新注入。
- 「用 In-app browser 開啟本頁」：SFSafariViewController 開得了 `http://127.0.0.1` 的內建網頁（不帶設定參數，顯示問題版與修正版的切換連結），沒有出現提示。
- log 裡沒有 Flutter 例外。

**Android（Pixel_4_API_32，API 32）**

- 這次用 `flutter emulators --launch Pixel_4_API_32` 啟動兩次都沒有開機成功：第一次模擬器行程自己結束，第二次卡住（adb 看不到裝置、行程的 CPU 時間不動）。改用無視窗啟動 `~/Library/Android/sdk/emulator/emulator -avd Pixel_4_API_32 -no-window -no-audio -no-boot-anim -no-snapshot-save` 才成功。
- 內建網頁載入成功；AppBar 標題同樣從「字體大小」換成「字體大小示範」；`onPageStarted` 比 `ready` 先到。
- 三個變體都切換得了，每次切換都重新載入，標題先回到「字體大小」。
- 字級：用 `adb shell settings put system font_scale 1.5` 調整（做完已用 `settings delete system font_scale` 還原成原本的未設定）。
  - 問題版：字變大（WebView 建立時自動套用系統字級），卡片最後一行被切掉。頁面開著時把字級改回 1.0，App 的介面變回原大小，網頁的字沒有變。
  - 修正版：網頁收到 `textScale` 1.50，根字級 150%，卡片不破版。字的大小和「只改 App」差不多，沒有放大成兩倍多，代表 `setTextZoom(100)` 有作用。頁面開著時改回 1.0，網頁即時變回 100%。
  - 只改 App：`setTextZoom(150)` 讓字變大，卡片仍被切掉。頁面開著時改字級，App 會重設放大倍率。
- 設定頁打開 Hybrid Composition 後回到示範頁，WebView 重建並載入，view hierarchy 出現 `FlutterMutatorView`。關掉後是 `PlatformViewWrapper`（TLHC）。
- 「用 In-app browser 開啟本頁」：Custom Tabs 叫出了 Chrome，但這台模擬器的 Chrome 沒有完成首次設定，停在 Chrome 的首次啟動畫面（繼續就要同意 Chrome 的服務條款）。這裡沒有代為同意，所以 Chrome 能不能載入 `127.0.0.1` 的內建網頁沒有確認。App 這邊 `launchUrl` 回傳成功，沒有出現提示。
- 每次用 `settings put system font_scale` 改字級，系統都會短暫顯示「Viewing full screen」提示（`ImmersiveModeConfirmation`），幾秒後自己消失。回到沒有 WebView 的首頁改字級也一樣會出現。App 沒有呼叫任何全螢幕 API，原因沒有查明。
- logcat 沒有 `FATAL EXCEPTION`，也沒有 Dart 例外。唯一的 `E flutter` 是 App 一啟動就出現的兩行 Impeller 訊息「EGL Error: Success (12288)」，出現在任何示範頁打開之前。

## 模擬器與裝置

- iOS 模擬器的執行環境：iOS 18.4、26.0、26.5、27.0。iOS 27.0 的 iPhone 有 iPhone 18 Pro、iPhone 18 Pro Max、iPhone 17e、iPhone Air、iPhone 17；另有數台 iPad。啟動方式：`xcrun simctl boot "iPhone 17"` 之後用 `flutter devices` 取得裝置代號，再 `flutter run -d <代號>`。
- Android 模擬器：`Pixel_4_API_32`（Android 12、API 32、arm64-v8a、Google Play 映像檔）。無視窗模式開機成功，`flutter devices` 認得到（`emulator-5554`）。系統 WebView 是 `com.google.android.webview` 152.0.7977.88。啟動方式：`flutter emulators --launch Pixel_4_API_32`。
- 這台只有一個 Android 模擬器，API 32。Android 14 以上才有的行為（非線性字級放大、高對比設定）在這個模擬器上看不到，要靠實機。
- 實機：檢查當下沒有連線的 iOS 或 Android 實機。

## 計畫指定的 API 是否存在

這張表最早是在第一台電腦上對照 SDK 與套件原始碼做的。這台的 Flutter 版本相同（3.47.5），`flutter pub add` 解析到的外掛版本也相同，所以另外在這台的 SDK 與 pub cache 原始碼裡用文字搜尋確認每個名稱都找得到。

| API | 結果 |
|---|---|
| `SemanticsService.sendAnnouncement(view, message, textDirection)` | 存在；`announce` 標示為 3.35 之後棄用 |
| `MediaQuery.supportsAnnounceOf` | 存在 |
| `MediaQuery.reduceMotionOf` | 不存在（和計畫的預期一致，計畫改讀 `AccessibilityFeatures.reduceMotion`） |
| `FocusSemanticEvent`、`RenderObject.sendSemanticsEvent` | 存在 |
| `PopScope.onPopInvokedWithResult` | 存在 |
| `WebViewController.setOnJavaScriptAlertDialog`／`ConfirmDialog`／`TextInputDialog`、`enableZoom`、`canGoBack` | 存在（webview_flutter 4.14.1） |
| `AndroidWebViewController.setTextZoom`、`AndroidWebViewWidgetCreationParams(displayWithHybridComposition:)` | 存在（webview_flutter_android 4.14.1） |
| `WebKitWebViewController.setAllowsBackForwardNavigationGestures` | 存在（webview_flutter_wkwebview 3.27.2） |
| `LaunchMode.inAppBrowserView`、`LaunchMode.externalApplication` | 存在（url_launcher 6.3.3） |

探測時 `flutter pub add` 解析到的版本：`webview_flutter` 4.14.1、`webview_flutter_android` 4.14.1、`webview_flutter_wkwebview` 3.27.2、`url_launcher` 6.3.3（都等於計畫的下限）。正式專案（`flutter_app/`，Task 2 建立）的 `pubspec.lock` 解析到的版本：`webview_flutter` 4.14.1、`webview_flutter_android` 4.14.1、`webview_flutter_wkwebview` 3.27.2、`url_launcher` 6.3.3、`shared_preferences` 2.5.6，五個都等於計畫的下限。

範本預設值：iOS 部署目標 15.0（計畫要求 ≥ 13.0）；Android `minSdk` 24（計畫要求 ≥ 24）、`compileSdk` 與 `targetSdk` 36；Android 範本含 `res/values-night/`。

## 未驗證的項目

- **所有報讀器行為**（TalkBack 與 VoiceOver）：沒有任何一項在實機上驗證過。iOS 模擬器不能執行 VoiceOver，TalkBack 在模擬器上的行為也不等於實機。
- **正式專案的 Android 原生設定**：明文 HTTP 設定、TLHC／Hybrid Composition 切換、`setTextZoom` 在模擬器上的表現見上面「Task 5 在模擬器上看到的結果」。報讀器在兩種顯示模式下的表現沒有驗證。
- **Android 的 In-app browser（Custom Tabs）能不能開啟內建網頁**：模擬器上停在 Chrome 的首次啟動畫面，沒有確認。
- **iPad 上 `-webkit-text-size-adjust` 是否有效**：沒有在 iPad 模擬器或實機上試。
- **Android 實機與 iOS 實機上的一切**，包括 iOS 實機載入 `http://127.0.0.1`（ATS 設定）與 In-app browser 能否開啟內建網頁：待 Task 5 的實機檢查點確認。
