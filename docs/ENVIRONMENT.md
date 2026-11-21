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

探測時 `flutter pub add` 解析到的版本：`webview_flutter` 4.14.1、`webview_flutter_android` 4.14.1、`webview_flutter_wkwebview` 3.27.2、`url_launcher` 6.3.3（都等於計畫的下限）。正式專案的版本在 Task 2 建立專案後補在這裡。

範本預設值：iOS 部署目標 15.0（計畫要求 ≥ 13.0）；Android `minSdk` 24（計畫要求 ≥ 24）、`compileSdk` 與 `targetSdk` 36；Android 範本含 `res/values-night/`。

## 未驗證的項目

- **所有報讀器行為**（TalkBack 與 VoiceOver）：沒有任何一項在實機上驗證過。iOS 模擬器不能執行 VoiceOver，TalkBack 在模擬器上的行為也不等於實機。
- **正式專案的 Android 原生設定**：`AndroidManifest.xml`、`network_security_config.xml`、TLHC／Hybrid Composition 切換、`setTextZoom`。上面的建置用的是拋棄式專案，正式專案從 Task 2、Task 3 開始才有可以建置和在模擬器上執行的內容，各任務的結果會補在這裡。
- **Android 實機與 iOS 實機上的一切**，包括 iOS 實機載入 `http://127.0.0.1`（ATS 設定）與 In-app browser 能否開啟內建網頁：待 Task 5 的實機檢查點確認。
