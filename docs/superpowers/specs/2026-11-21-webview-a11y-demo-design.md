# Flutter WebView 無障礙範例：設計文件

- 日期：2026-11-21
- 狀態：第二版，已依獨立審查修正，待使用者確認
- 對應實作計畫：`docs/superpowers/plans/2026-11-21-webview-a11y-demo.md`

## 1. 目的

使用者的工作專案是一個要做無障礙的 Flutter App，裡面用 WebView 開了不少網頁。這個範例要讓使用者**拿著手機、開著 TalkBack 或 VoiceOver 實際操作**，理解：

1. 即使 App 和網頁各自都做了無障礙，哪些地方仍然會出問題。
2. 每個問題的「問題版」和「修正版」差在哪裡，修正要改在 App、網頁，還是兩邊。

成品是兩個專案：`flutter_app/`（範例 App）和 `web/`（配合的網頁）。

**目標**
- 每個問題一頁，可以在問題版和修正版之間切換，頁面上有「怎麼測」。
- 修正版的程式碼可以當成參考實作，搬回正式專案。
- App 預設不需要網路也不需要另外架伺服器。

**非目標**
- 不示範只靠單邊就能做好、和 WebView 無關的無障礙（網頁語意化、Flutter 元件的 Semantics）。這些在範例裡一律「做對」當背景。
- 不是正式產品，不處理正式環境的資安設定（明文 HTTP 只為了示範）。

**反目標（做了就算失敗）**
- 示範效果誤導人。沒有可靠修法的問題，頁面必須標成「觀察頁」，不能假裝修好。
- 問題版和修正版之間，除了該頁要示範的修正以外還有其他差異。
- 同一件事被報讀器念兩次，讓人分不出是哪個修正在起作用。

## 2. 查證方式與可信度

技術事實的來源（2026-11-21）：

- 四個研究代理對照 pub.dev 與 api.flutter.dev 官方文件、Chromium／WebKit／flutter/packages 原始碼（main 分支）、Android 與 Apple 開發者文件、flutter/flutter 的 issue。
- 一個獨立審查代理另外複核：文件引用的 13 個 issue 都存在且狀態相符；Android WebView 的字級機制；iOS 上 JS 對話框和 `target=_blank` 的行為；Flutter 在 Android 一律回報不支援 announcement；`reduceMotionOf` 的可用版本。
- Issue 編號和原始碼結論來自代理的回報，撰寫者沒有逐一重讀。

**沒有任何一項在實機上跑過。** 每一頁標一個可信度：

| 標示 | 意思 |
|---|---|
| 已查證 | 官方文件或原始碼明確支持。實機仍應確認，但預期如文件所述 |
| 需實機確認 | 來源互相矛盾、只有 issue 回報、是從機制推論的，或結果取決於報讀器本身的行為 |
| 觀察頁 | 沒有可靠修法，或正確做法因裝置而異。頁面提供觀察清單、可比較的組合和繞過方式 |

## 3. 對先前清單的更正

先前在對話中列過兩次清單，以下說法經查證後需要更正：

| # | 先前的說法 | 查證結果 | 來源 |
|---|---|---|---|
| 1 | 系統字體調大，網頁不會變 | **Android 不是這樣。** Android WebView 建立時會自動套用系統字級，之後不再追蹤；`setTextZoom` 一旦呼叫就取代自動行為。iOS 的 WKWebView 預設不跟，但網頁可以用 `font: -apple-system-body` 自己跟隨 | Chromium `AwSettings.java`；WebKit bug 187013 |
| 2 | 用 `SemanticsService.announce` 朗讀 | 這個 API 已棄用（v3.35 之後），改用 `sendAnnouncement(view, …)`。而且 **Flutter 在所有 Android 版本都回報不支援 announcement**，所以它實際上只在 iOS 有效。Android 要用 Semantics 的 `liveRegion` | api.flutter.dev；Flutter engine `AccessibilityBridge.java` |
| 3 | Flutter 沒有 API 能指定報讀器焦點 | 有：`FocusSemanticEvent`（Android、iOS）。官方文件說一般不建議使用 | api.flutter.dev |
| 4 | `target=_blank` 點了沒反應 | 目前的外掛在兩個平台都會在同一個 WebView 裡開啟。真正會失敗的是 `tel:`、`mailto:` | webview_flutter 原始碼 |
| 5 | TLHC 模式焦點框偏移、點兩下點錯位置 | 查無 issue 佐證。有佐證的是：TLHC 下疊在 WebView 上方的 Flutter 元件（浮動按鈕、Drawer、對話框），TalkBack 用手指觸摸探索點不到 | flutter/flutter#101887（未修） |
| 6 | Flutter 對話框蓋在網頁上，下層網頁還摸得到 | 「下層網頁被讀到」在 Android 的 Hybrid Composition 已於 2021 年修掉（#80765）。但「對話框自己的按鈕點不到」在預設的 TLHC 模式仍未修（#101887），而且 2026-08 有人回報 Hybrid Composition 在 release 版也失敗 | #80765、#101887 |
| 7 | 深色模式要靠 App 傳給網頁 | WebView 的 `prefers-color-scheme` 不跟 Flutter 的 `ThemeMode`。iOS 跟 WKWebView 所在畫面的外觀（通常等於系統）。**Android 跟的是 Activity 原生主題的 `isLightTheme`**，也就是 `values/styles.xml` 和 `values-night/styles.xml`；專案沒有 `values-night` 的話 WebView 永遠是淺色。另外網頁要有 `<meta name="color-scheme">` | developer.android.com dark-theme；WebKit 原始碼 |
| 8 | 減少動態要靠 App 傳 | `prefers-reduced-motion` 兩個平台原生都支援。`prefers-contrast` 在 iOS 支援、Android 未證實。粗體文字沒有對應的 media query，才真的需要 App 傳 | Chromium、WebKit 原始碼 |
| 9 | （原清單沒有）| iOS 上網頁呼叫 `alert()`／`confirm()`／`prompt()`，若 App 沒註冊處理函式，會被**靜默取消**：`confirm` 回傳 false、`prompt` 回傳空字串。Android 會顯示系統對話框 | webview_flutter_wkwebview 原始碼 |
| 10 | 離開 WebView 頁後焦點復原「無解」 | 有 `FocusSemanticEvent` 可以嘗試。另外這個問題是所有 Flutter 頁面共通的，不是 WebView 特有 | 同 #3 |

## 4. 需要處理的項目總表

依「誰能修」分成三類，另加工具頁：

| 類別 | 意思 | 網頁團隊需要參與嗎 |
|---|---|---|
| **C 兩邊約定** | App 和網頁要約好參數、訊息和責任分工，缺一邊就不成立 | 要 |
| **A App 單方處理** | 網頁本身沒問題，但放進 WebView 後要 App 接手處理，或 App 的包法出錯 | 不用 |
| **B 交界處限制** | Flutter 嵌入原生 WebView 的機制造成的問題。有些能靠 App 的版面繞過，有些只能觀察 | 不用 |
| **T 工具** | 不是問題，是幫助判斷問題的對照頁 | — |

使用者原本問的「需要配合的地方」對應 C 類；「交界處問題」對應 B 類。A 類是審查後新分出來的：這些項目一樣要處理，但不需要兩個團隊協調。

### 4.1 C 類：兩邊約定（11 頁）

| 代號 | 項目 | 修正方 | 可信度 | 一句話說明 |
|---|---|---|---|---|
| C01 | 字體大小 | 兩邊 | 已查證 | iOS 網頁預設不跟系統字級；Android 會跟但不即時更新，而且兩邊都處理時會重複放大 |
| C02 | 深淺色主題 | 兩邊 | 需實機確認 | WebView 跟的不是 App 的主題設定 |
| C03 | 粗體、高對比、減少動態 | 兩邊 | 需實機確認 | 有些設定網頁自己偵測得到，有些只有 App 知道 |
| C04 | 語系 | 兩邊 | 需實機確認 | 網頁的語系要跟 App 決定的一致，不然內容和報讀器語音都可能錯 |
| C05 | 標題與重複導覽 | 兩邊 | 已查證 | AppBar 和網頁 header 各有一份標題和返回鍵 |
| C06 | 頁面抵達：朗讀與焦點 | 擇一 | 需實機確認 | 網頁內換頁（SPA）時報讀器沒有任何提示 |
| C07 | 返回、瀏覽紀錄與關閉 | 兩邊 | 需實機確認 | 按返回直接關掉整頁；網頁的「完成」按鈕關不掉畫面 |
| C08 | 縮放 | 兩邊 | 需實機確認 | App 或網頁任一邊關掉縮放，低視能使用者就不能放大 |
| C09 | 網頁叫出原生對話框 | 兩邊 | 需實機確認 | 原生對話框關閉後，焦點沒有回到網頁 |
| C10 | 原生按鈕送出網頁表單 | 擇一 | 需實機確認 | 按 App 的「送出」，網頁驗證失敗，但報讀器使用者聽不到錯誤 |
| C11 | 安全區域與鍵盤遮擋 | 兩邊 | 觀察頁 | 網頁底部固定按鈕被 Home 指示條或鍵盤擋住。哪一邊處理才對因版面而異 |

### 4.2 A 類：App 單方處理（5 頁）

| 代號 | 項目 | 可信度 | 一句話說明 |
|---|---|---|---|
| A01 | 載入中與錯誤 | 已查證 | 載入中只有視覺轉圈；失敗時是系統錯誤頁或白畫面 |
| A02 | JS 對話框 | 已查證 | iOS 上 `confirm()` 被靜默取消，使用者不知道發生什麼 |
| A03 | 電話、信箱、外部連結 | 需實機確認 | `tel:`、`mailto:` 點了出錯或沒反應 |
| A04 | 外層包裝 | 需實機確認 | `ExcludeSemantics` 讓網頁整個讀不到；`IgnorePointer` 讓明眼人和報讀器使用者得到不同結果 |
| A05 | 被遮住或隱藏的 WebView | 需實機確認 | Flutter 遮罩蓋在 WebView 上，報讀器仍可能讀到下層網頁 |

### 4.3 B 類：交界處限制（5 頁）

| 代號 | 項目 | 平台 | 可信度 | 依據 |
|---|---|---|---|---|
| B01 | 疊在 WebView 上方的 Flutter 元件點不到 | Android | 需實機確認 | #101887（未修，2026-08 仍有更新）：TLHC 下觸摸探索無法聚焦疊在 Platform View 上的元件，滑動可以。Hybrid Composition 在 2022 年修過，但 2026-08 有 release 版仍失敗的回報 |
| B02 | 焦點進出、觸摸探索與朗讀 | 兩者 | 觀察頁 | iOS #30804（未修）：手指直接摸網頁內容無法聚焦，滑動可以。iOS #87030（未修，舊）：滑進網頁後回不到 AppBar。iOS #65027（未修，舊）：點多行輸入框後焦點跳到 AppBar。Android #158004（未修）：App 開著時關掉再開 TalkBack，網頁內容無法聚焦 |
| B03 | WebView 放在可捲動容器裡 | 兩者 | 需實機確認 | iOS #194389（未修，2026-10）：在可捲動容器內，觸摸探索到不了 Platform View 的內部元素。#181556：網頁在可捲動清單內無法捲動或縮放 |
| B04 | 離開 WebView 頁後的焦點復原 | 兩者 | 需實機確認 | 所有 Flutter 頁面共通的問題，這一頁拿 WebView 頁和純 Flutter 頁對照。`FocusSemanticEvent` 可嘗試；#137235（未修）：iOS 上 `FocusNode.requestFocus()` 不會移動 VoiceOver 焦點 |
| B05 | 外接鍵盤、Switch Access、Voice Access | 兩者 | 觀察頁 | #40911、#40913（2019，未確認）；#130652（未修）：Android 上先在 Flutter 輸入框打字後，網頁表單收不到實體鍵盤輸入 |

Android 的顯示模式（TLHC／Hybrid Composition）是**全域設定**，每一頁都可以切換後重測。

### 4.4 T 類：工具頁（2 頁）

| 代號 | 項目 | 用途 |
|---|---|---|
| T01 | 診斷對照表 | 網頁並列顯示「自己偵測到的」和「App 傳進來的」每一項設定，以及網頁回報的約定版本與能力。在自己的裝置上一眼看出哪些設定網頁偵測不到 |
| T02 | 改用 In-app browser | 說明取捨，並用 SFSafariViewController／Custom Tabs 開同一份網頁對照。每一頁的 AppBar 也都有「用 In-app browser 開啟本頁」 |

### 4.5 列出但不做示範頁

| 項目 | 類別 | 說明 |
|---|---|---|
| 檔案上傳 | A | Android 上 `<input type=file>` 預設點了沒反應，要註冊 `AndroidWebViewController.setOnShowFileSelector`。iOS 原生可用，但 `Info.plist` 要有相機和相簿的用途說明，否則選拍照會當掉。主要是功能失效，不是無障礙特有，所以不做頁面 |
| 相機、麥克風、定位權限請求 | A | 同上的模式：沒有原生處理就靜默失敗。設定點是 `onPermissionRequest` |
| 媒體自動播放、iOS 影片強制全螢幕 | A | 設定點是 `setMediaPlaybackRequiresUserGesture`、`allowsInlineMediaPlayback` |
| 下載與 PDF 連結 | A | 行為需實機確認，放在 A03 的說明裡當觀察項 |
| 登入逾時、重新登入的交接 | C | 模式和 C09、A01 相同（原生畫面交接加狀態朗讀） |
| 約定版本與能力握手 | C | App 無從得知載入的頁面有沒有實作約定。範例做到：網頁在 `ready` 回報版本與能力、App 用網域判斷是否套用「網頁負責字級」（見 §6.1）。依能力逐項自動切換策略不做 |
| 告訴網頁「使用者正在用報讀器」 | C | 技術上可用 `MediaQuery.accessibleNavigationOf` 傳，但偵測輔助科技有隱私爭議，不建議當預設做法 |
| 連結說明要符合 App 的實際行為 | C | 網頁若寫「另開新視窗」，App 實際上卻在同一個 WebView 開，報讀器使用者會被誤導。範例的連結文字一律不做這類宣稱 |
| debug 和 release 建置的差異 | B | 報讀器行為可能不同（#101887 有相關回報），TalkBack 在 debug 版也很慢。README 規定用 profile 或 release 建置來測 |
| TalkBack 開啟時的效能 | B | #196261 是 Flutter 整體問題，不是 WebView 特有 |
| 非 WebView 根節點的 Platform View 被跳過 | B | #196560 不適用 `webview_flutter`（根節點就是 WebView） |
| 螢幕方向鎖定 | — | App 單邊設定，和 WebView 無關 |

## 5. 架構

```
a11y-webview-demo/
├── README.md
├── docs/CONTRACT.md, docs/ENVIRONMENT.md, docs/superpowers/{specs,plans}/
├── web/                         ← 純 HTML/CSS/JS，沒有框架、沒有建置步驟、不載入外部資源
│   ├── index.html               ← 瀏覽器單獨開啟時的目錄
│   ├── shared/a11y-app.js       ← 約定的網頁端實作
│   ├── shared/base.css
│   ├── pages/*.html             ← 每個示範一頁
│   └── test/                    ← 自我測試（瀏覽器和 Node 都能跑）
└── flutter_app/
    ├── assets/web/              ← web/ 的複本，由 tool/sync_web.sh 產生，納入版控
    ├── tool/sync_web.sh
    └── lib/
        ├── main.dart, app.dart
        ├── contract/            ← URL 參數、Bridge 訊息、返回決策、導覽與錯誤判斷（純 Dart，可單元測試）
        ├── server/local_web_server.dart
        ├── settings/            ← 網頁來源、App 主題、Android 顯示模式
        ├── catalog/             ← 每個示範頁的宣告（DemoSpec）
        ├── webview/             ← DemoWebView：所有修正都打開的參考包裝
        ├── widgets/             ← 共用頁框
        └── demos/               ← 需要特殊版面的示範頁
```

### 5.1 網頁來源（已決定：兩種都支援）

- **內建（預設）：** App 啟動時用 `dart:io` 的 `HttpServer` 綁在 `127.0.0.1` 的隨機埠，從 App 的 assets 提供網頁。用 `127.0.0.1` 而不是 `localhost`，避免解析到 IPv6。
- **外部：** 設定頁輸入網址。網頁專案用 `python3 -m http.server` 啟動，Android 模擬器用 `10.0.2.2`。
- App 從背景回到前景時要確認內建伺服器還活著（iOS 會在 App 暫停時回收 socket），必要時在原來的埠重新啟動。

**為什麼不用 `loadFlutterAsset` 直接載入：** `file://` 不適合帶查詢參數、`history.pushState` 受限、In-app browser 也開不了。用 HTTP 才能讓 WebView、In-app browser 和一般瀏覽器開同一份網頁。

**這個伺服器只適合示範：** 同一台裝置上的其他 App 也連得到它。正式專案的網頁來自 HTTPS 網站，不需要這個伺服器。

**明文 HTTP 的設定（僅供示範）**
- Android：`network_security_config.xml` 用 `<base-config cleartextTrafficPermitted="true"/>`。不用 `usesCleartextTraffic`，官方文件說它將被棄用。
- iOS：`NSAppTransportSecurity` 設 `NSAllowsLocalNetworking` 和 `NSAllowsArbitraryLoadsInWebContent`。Apple 文件對 iOS 17 以上 IP 位址的規則自相矛盾，所以兩個都設，在實機確認。
- In-app browser 能不能開 `127.0.0.1` 上的內建網頁，沒有找到可靠來源。開不了時畫面要明確告知，並建議改用外部來源。

### 5.2 基準原則

共用的 `DemoWebView` **預設把所有修正都打開**（基準）。每一頁的問題版**只關掉該頁自己要示範的那一項**。網頁端同理：每頁宣告自己示範哪些修正，只有那些可以被關掉。

基準的修正不能改變其他頁問題版的樣子。已知的兩個干擾點和處理方式：

- **錯誤畫面：** 基準會在載入失敗時用 Flutter 畫面取代 WebView，但只針對「目前頂層載入的 http(s) 網址失敗」。`tel:` 這類非 http(s) 的失敗、被取消的載入（iOS 的 -999 和 102）一律不取代，否則 A03 問題版會看不到原本的錯誤頁。
- **朗讀：** 基準不主動朗讀頁面標題（見 §6.4），否則每一頁的焦點移動都會被念兩次。

### 5.3 變體

每頁有一到四個變體，預設是「問題版／修正版」。需要比較不同做法時可以更多，例如 C06 把「網頁移焦點」和「App 朗讀」分成不同變體。切換變體時 WebView 整個重建（Android 的字級和顯示模式都是在建立時決定的）。

### 5.4 共用頁框

```
┌────────────────────────────────────┐
│ ← 字體大小            [瀏覽器][重載][設定] │  AppBar：標題來自網頁回報
├────────────────────────────────────┤
│ (問題版) (修正版) (只改 App)            │  變體選擇
│ 修正在：兩邊 · 已查證 · 兩個平台          │  標示
│ ▸ 怎麼測                              │  可收合：前置、步驟、預期、依據、看哪些檔案
├────────────────────────────────────┤
│                                    │
│              WebView               │
│                                    │
└────────────────────────────────────┘
```

首頁依 C／A／B／T 分區列出所有頁面，每列顯示代號、標題、修正方、可信度、平台。

## 6. App 與網頁的約定

這是範例示範的參考約定，也是使用者的兩個團隊實際上需要談定的東西。完整版另外放在 `docs/CONTRACT.md`。

### 6.1 App → 網頁：URL 參數（載入時）

| 參數 | 值 | 意思 |
|---|---|---|
| `mode` | `problem`／`fixed` | **範例專用。** `problem` 關掉這一頁宣告的所有修正。缺少時視為 `fixed` |
| `off` | 逗號分隔的修正名稱 | **範例專用。** 只關掉指定的修正，用來單獨比較某一種做法。不是本頁宣告的名稱會被忽略 |
| `embedded` | `1` | 網頁在 App 的 WebView 裡。In-app browser 和一般瀏覽器不帶 |
| `lang` | BCP 47，例如 `zh-TW` | App 決定的語系 |
| `theme` | `light`／`dark` | App 實際顯示的主題 |
| `textScale` | `0.80`–`3.00`，兩位小數 | App 的字級倍率。有帶這個參數代表「由網頁負責放大」 |
| `bold`、`contrast`、`reduceMotion` | `0`／`1` | 粗體文字、高對比、減少動態 |

參數順序固定為上表順序。網頁對每個值做白名單驗證，不合法就當作沒帶。

**字級的責任歸屬（避免重複放大）**

| 策略 | App 做什麼 | 網頁做什麼 | 用在 |
|---|---|---|---|
| 網頁負責（基準） | 傳 `textScale`；Android 另外呼叫 `setTextZoom(100)` 關掉 WebView 自己的放大 | 根字級設為 `100% × textScale`，全部用 `rem` | 確定有實作約定的自家網頁 |
| App 負責 | 不傳 `textScale`；Android 呼叫 `setTextZoom(倍率×100)` 並在字級改變時重設；iOS 注入 `-webkit-text-size-adjust`（iPad 是否有效需確認） | 不用改，但寫死高度的版面仍可能破版 | 改不到的網頁 |
| 網頁自理（只有 iOS） | 無 | `html { font: -apple-system-body }`，跟隨 iOS 動態字級 | 範例不採用，在 T01 顯示偵測值供參考 |
| 都不做 | 無 | 無 | C01 問題版 |

- **「網頁負責」只套用在自家網域。** WebView 導到其他網域時（例如 A03 問題版裡的外部連結），那個頁面沒有實作約定，如果仍維持 `setTextZoom(100)`，大字級使用者看到的字反而變小。所以 App 以目前頂層網址是否在自家網域內為準：是就用「網頁負責」，不是就改用「App 負責」。「目前頂層網址」指已經換上、正在畫面上的那一頁（見 §6.3）；iOS 的 `-webkit-text-size-adjust` 只作用在單一份文件，所以只在頁面載入完成後注入到已換上的那一頁，載入中一律不注入。
- `textScale` 的算法：`MediaQuery.textScalerOf(context).scale(16) / 16`，限制在 0.8 到 3.0，四捨五入到兩位小數。Android 14 以上 Flutter 的字級放大不是線性的，這個算法取的是 16px 內文的倍率。

### 6.2 App → 網頁：執行中呼叫

| 呼叫 | 時機 |
|---|---|
| `window.a11yApp.updateSettings({...})` | 收到網頁的 `ready` 之後送一次；之後系統設定或 App 主題改變時再送 |
| `window.a11yApp.handleBack()` | 使用者按返回，而網頁先前回報過自己有東西要關 |
| `window.a11yApp.onNativeDialogClosed(requestId, action)` | 網頁要求的原生對話框關閉 |
| `window.a11yApp.submitForm()` | 使用者按了 App 的送出按鈕 |
| `window.a11yApp.reportReady()` | 頁面載入完成、屬於自家網域，但 App 還沒收到這一頁的 `ready`。例如從其他網域導回自家網頁時，網頁在載入過程中送的 `ready` 依 §6.3 會被忽略，App 在載入完成後請網頁補送 |

呼叫時網頁腳本可能還沒載入，所以 App 的每個呼叫都先檢查 `window.a11yApp` 存在；設定則靠「收到 `ready` 後重送」確保不漏。

### 6.3 網頁 → App：`A11yBridge.postMessage(JSON)`

| `type` | 欄位 | 意思 |
|---|---|---|
| `ready` | `title`、`lang`、`contract`、`caps` | 頁面可用了。`contract` 是約定版本（目前是 1），`caps` 是這一頁啟用的修正名稱清單。從 bfcache 回來時（`pageshow`）要再送一次 |
| `routeChanged` | `title`、`path` | 網頁內換頁 |
| `backState` | `canHandleBack` | 網頁內有對話框之類要先關的東西 |
| `openNativeDialog` | `requestId`、`title`、`message`、`actions` | 請 App 顯示原生對話框 |
| `formResult` | `ok`、`errorCount`、`firstError`（可省略） | 表單驗證或送出的結果 |
| `close` | 無 | 請 App 關閉整個 WebView 畫面 |

- `A11yBridge` 不存在時（一般瀏覽器），網頁端靜默略過。
- App 收到無法解析或不認得的訊息時忽略，不能當掉。
- **信任範圍：** JS 頻道會注入到頁面裡所有的 frame，包括 iframe。App 只在目前頂層網址屬於自家網域時才處理訊息，其他情況一律忽略。
  - **「目前頂層網址」是已經換上、正在畫面上的那一頁。** iOS 的 WKWebView 在開始載入新頁面（provisional navigation）時就回報新網址（`onPageStarted`、`onUrlChange`），這時畫面上仍是舊頁面，舊頁面仍可能送訊息；Android 的 `onPageStarted` 則在新頁面換上時才觸發。為了兩個平台一致，App 把頂層網址分成「已換上」與「載入中」：頁面載入完成（`onPageFinished`）才算換上，但只限這次載入有 `onPageStarted` 的情況（Android 導向回 204 的網址或取消導覽時，只送一次 `onPageFinished`、畫面仍是原本的頁面；這種沒有 `onPageStarted` 的 `onPageFinished` 只結束載入中，已換上的網址不變）；主框架載入失敗或被取消就結束載入中，並以 WebView 最後回報的網址作為已換上的網址（iOS 在新頁面換上前取消時，會先把網址變回原本的；新頁面換上後才被 `window.stop()` 之類停止時，網址不會變回去，畫面上的是新頁面）；App 自己發起的載入（第一次載入、重新載入、`loadUri`）在呼叫時就記為載入中（iOS 第一次載入時 `onUrlChange` 可能比 `onPageStarted` 早好幾秒）；沒有載入中時的 `onUrlChange`（網頁內換頁、錨點）直接更新已換上的網址，但網址的 scheme、host 或埠和已換上的不同時（網頁內換頁不可能改變這三者），視為開始載入新頁面、記為載入中。
  - **載入中時，只有已換上的網址與載入中的網址都屬於自家網域才處理訊息。** 這個 WebView 還沒換上過任何頁面時（第一次載入），只看載入中的網址。
  - 新頁面屬於自家、舊頁面不屬於時，新頁面在載入過程中送的 `ready` 會被忽略；App 在載入完成後若還沒收到這一頁的 `ready`，呼叫 `reportReady()` 請網頁補送（§6.2）。
  - **殘留風險：** 自家頁面裡的跨網域 iframe 也收得到頻道，而外掛的訊息不帶來源 frame，App 無法分辨。自家網頁不應嵌入不受信任的 iframe。另外，`webBase` 的路徑只是方便的界線，不是安全邊界：同一個 origin 上、`webBase` 路徑以外的頁面可以用 `history.pushState` 把網址改到 `webBase` 之下。

### 6.4 朗讀由誰負責

原則：**一件事只用一種方式讓使用者知道。**

1. **會移動焦點的事件**（網頁內換頁、表單驗證失敗、對話框關閉）：由焦點落點本身被念出來。App 只安靜地更新 AppBar 標題，不另外朗讀。
2. **不移動焦點的狀態變化**（載入中、載入完成、送出成功）：用 `liveRegion`（App 端）或 `aria-live`（網頁端）。狀態顯示在哪一邊就由哪一邊負責，另一邊不重複。
3. `sendAnnouncement` 只在 iOS 有效；要兩個平台一致就用 `liveRegion`。

基準採用第 1 點：網頁換頁時移焦點，App 不朗讀。C06 和 C10 把「網頁移焦點」和「App 朗讀」拆成不同變體，讓使用者分別聽到效果，並在自己的裝置上判斷哪個可靠。「網頁的 `aria-live` 在報讀器焦點停在 Flutter 元件上時會不會被念出來」沒有查到可靠來源，列為 B02 的觀察項。

## 7. 各頁設計

每頁列出：變體、網頁端和 Flutter 端在各變體的差異、怎麼測的重點。「怎麼測」的完整文字由實作者依此撰寫，放在頁面上和 README。

### C01 字體大小
- 變體：問題版／修正版／只改 App
- 網頁 `c01-text-scale.html`：問題版用 `px` 字級加固定高度的卡片；修正版用 `rem`、不固定高度、根字級跟 `textScale`
- Flutter：問題版不做事；修正版用「網頁負責」策略；只改 App 用「App 負責」策略（網頁維持問題版）
- 怎麼測：把系統字級調到最大後進入頁面。再試一次：頁面開著時切到系統設定改字級再回來
- 預期：問題版在 iOS 網頁字不變大；在 Android 字變大但卡片文字被切掉，且開著時改字級網頁不更新。修正版兩個平台都跟著變、不破版、即時更新。只改 App 版字會變大但卡片仍破版（說明網頁還是得配合）；iPad 上可能無效

### C02 深淺色主題
- 變體：問題版／修正版
- 網頁 `c02-theme.html`：兩版都有 `<meta name="color-scheme">` 和兩組配色。問題版只看 `prefers-color-scheme`；修正版 `theme` 參數優先
- Flutter：問題版不傳 `theme`；修正版傳，並在 App 主題改變時即時通知
- 怎麼測：到設定把 App 主題改成和系統相反。另外測一次：頁面開著時切換系統深色模式
- 預期：問題版網頁不跟 App；修正版和 App 一致。Android 上問題版跟的是原生主題，頁面開著時切換系統深色模式不一定會更新
- 給正式專案的檢查點：確認 `android/app/src/main/res/values-night/styles.xml` 存在

### C03 粗體、高對比、減少動態
- 變體：問題版／修正版
- 網頁 `c03-a11y-prefs.html`：一段動畫、一段內文、一組低對比的輔助文字。問題版只用 media query；修正版在 media query 偵測不到時採用 App 傳來的值
- Flutter：問題版不傳三個旗標；修正版傳。減少動態的值是 Android 的「移除動畫」或 iOS 的「減少動態效果」任一為真
- 怎麼測：分別打開系統的粗體文字、增加對比／高對比文字、減少動態／移除動畫，各進一次頁面；搭配 T01 看哪些是網頁自己偵測到的
- 預期：依裝置而異。粗體沒有 media query，問題版一定不會變粗。Flutter 只在 iOS 13 以上和 Android 14 以上收得到高對比設定，較舊的 Android 上 App 會回報「關閉」

### C04 語系
- 變體：問題版／修正版；頁面上另有「App 語系（模擬）」選單：`zh-TW`／`en`
- 網頁 `c04-lang.html`：有中英兩份內容。問題版用 `navigator.language` 決定內容和 `<html lang>`；修正版用 `lang` 參數
- Flutter：問題版不傳 `lang`；修正版傳選單的值
- 怎麼測：選一個和手機目前語言不同的語系
- 預期：問題版內容不跟 App 的選擇；修正版跟。報讀器會不會切換到對應語音取決於報讀器和語音引擎。iOS 的 `navigator.language` 跟的是 App 的語系設定（由 `Info.plist` 的 `CFBundleLocalizations` 決定），不一定等於系統語言

### C05 標題與重複導覽
- 變體：問題版／修正 A（AppBar 當標題）／修正 B（網頁保留標題）
- 網頁 `c05-title.html`：有自己的 header（網站名稱、`<h1>`、回上一頁連結）。修正 A 在 App 內隱藏整個 header；修正 B 只隱藏網站名稱和返回連結，保留 `<h1>`
- Flutter：問題版和修正 B 的 AppBar 顯示固定文字「WebView 範例」；修正 A 用網頁回報的標題
- 怎麼測：用報讀器從頭滑過整頁；用標題導覽（VoiceOver 轉子、TalkBack 閱讀控制項）跳標題
- 預期：問題版聽到兩個返回，標題出現在兩個地方。修正 A 只有 AppBar 一個標題，網頁內容從第二層標題開始。修正 B 只有網頁一個頁面標題
- 取捨：基準採用修正 A。它的代價是網頁內沒有第一層標題；標題導覽能不能從 AppBar 跨到網頁需實機確認

### C06 頁面抵達：朗讀與焦點
- 變體：問題版／修正 A（網頁移焦點）／修正 B（App liveRegion）／修正 C（App sendAnnouncement，僅 iOS）
- 網頁 `c06-arrival.html`：兩個畫面的 SPA（清單、詳情），用 `history.pushState` 換頁。問題版換頁時不回報也不移焦點（載入時的 `ready` 握手照常送）。修正 A 回報並把焦點移到新畫面的標題（`tabindex="-1"`）。修正 B、C 只回報、不移焦點
- Flutter：修正 A 只安靜地更新 AppBar 標題。修正 B 把 AppBar 標題設為 `liveRegion`。修正 C 在 `MediaQuery.supportsAnnounceOf` 為 true 時呼叫 `sendAnnouncement`，為 false 時在頁面上顯示「Flutter 在這個平台不支援 announcement，請用 liveRegion」
- 怎麼測：用報讀器點清單項目進入詳情，注意聽到什麼、焦點在哪
- 預期：問題版沒有任何提示，焦點停在已消失的項目。修正 A 念出新標題且焦點在新標題。修正 B 念出新標題但焦點沒動。修正 C 在 iOS 念出新標題，在 Android 顯示不支援

### C07 返回、瀏覽紀錄與關閉
- 變體：問題版／修正版
- 網頁 `c07-back.html`：三步驟流程、一個頁內對話框、最後一步有「完成」按鈕。問題版換步驟不寫入瀏覽紀錄、對話框不回報、「完成」呼叫 `window.close()`。修正版用 `pushState`，對話框開關時送 `backState` 並實作 `handleBack()`（關閉後焦點回到觸發按鈕），「完成」送 `close`
- Flutter：問題版是一般頁面，返回直接離開，不處理 `close`。修正版用 `PopScope`，`canPop` 隨時等於「網頁沒有東西要關，且沒有上一頁」；返回時先請網頁關對話框，再回網頁上一步，都沒有才離開；收到 `close` 就關閉頁面。iOS 另開啟 WKWebView 的邊緣滑動返回
- 怎麼測：走到第三步再按返回；打開對話框再按返回；按「完成」。Android 用返回手勢。iOS 用 AppBar 返回按鈕、邊緣滑動，以及 VoiceOver 的雙指 Z 手勢（焦點在網頁內和在 AppBar 上各試一次）
- 預期：問題版一按就離開，「完成」沒反應。修正版依序關對話框、回上一步、最後才離開，「完成」會關閉。雙指 Z 手勢在焦點位於網頁內時是否有效需實機確認
- 注意：在第一步（`canPop` 為 true）時，WKWebView 的滑動返回和 Flutter 頁面的滑動返回用的是同一個邊緣

### C08 縮放
- 變體：兩邊都關（問題版）／只關 App／只關網頁／都開（修正版）
- 網頁 `c08-zoom.html`：「關」的時候 viewport 有 `user-scalable=no, maximum-scale=1`
- Flutter：「關」的時候 `enableZoom(false)`
- 怎麼測：每個變體都試雙指放大
- 預期：只有「都開」確定能放大。另外兩個單邊變體用來確認任一邊關掉就不行；實際結果需實機確認
- 平台事實：iOS 的 `enableZoom(false)` 其實是注入一段 viewport 設定，也是走網頁層；Android 的外掛預設 `setUseWideViewPort(false)`，對 viewport meta 的處理和 Chrome 不同

### C09 網頁叫出原生對話框
- 變體：問題版／修正版
- 網頁 `c09-native-dialog.html`：「刪除項目」按鈕送 `openNativeDialog`。兩版都會在 `onNativeDialogClosed` 後更新畫面。修正版另外管理焦點：取消時回到觸發按鈕；確認刪除後移到結果訊息（`tabindex="-1"`）
- Flutter：兩版都顯示 `AlertDialog` 並回呼網頁
- 預期：問題版對話框關閉後焦點位置不明、沒有結果提示；修正版焦點落在按鈕或結果訊息上。焦點能不能從 Flutter 對話框回到 WebView 內的元素需實機確認

### C10 原生按鈕送出網頁表單
- 變體：問題版／修正 A（網頁處理）／修正 B（App liveRegion）；版面：WebView 下方有 Flutter 的「送出」按鈕
- 網頁 `c10-native-submit.html`：姓名、Email 兩個必填欄位。問題版驗證失敗只顯示紅字。兩個修正版都會設 `aria-invalid`、用 `aria-describedby` 連結錯誤訊息、送 `formResult`。修正 A 另外把焦點移到第一個錯誤欄位，成功時把訊息寫進網頁的 `aria-live` 區域；修正 B 不做這兩件事
- Flutter：按鈕呼叫 `submitForm()`。修正 B 在按鈕上方用 `liveRegion` 文字顯示結果
- 預期：問題版按送出後報讀器沒有提示。修正 A 是否有效取決於焦點能不能從 Flutter 按鈕跳進網頁、以及網頁的 `aria-live` 在焦點位於 Flutter 時會不會被念。修正 B 會念出錯誤數量和第一個錯誤

### C11 安全區域與鍵盤遮擋（觀察頁）
- 變體：都不處理／只改 App／只改網頁／兩邊都做
- 網頁 `c11-safe-area.html`：長表單加底部固定的按鈕列。「改網頁」是指 `viewport-fit=cover`、`env(safe-area-inset-bottom)`、`scroll-padding-bottom`，以及輸入框聚焦時捲到可見位置
- Flutter：「改 App」是指用 `SafeArea` 包住 WebView。`Scaffold` 預設會在鍵盤出現時縮小內容區
- 觀察：每個組合下，最後一個輸入框聚焦時有沒有被按鈕列或鍵盤擋住；底部按鈕有沒有被 Home 指示條擋住；兩邊都做時有沒有多出空白
- 依據：WCAG 2.2 的 2.4.11「焦點不被遮蔽」

### A01 載入中與錯誤
- 變體：問題版／修正版；頁面有兩個按鈕：「慢速重新載入」、「載入不存在的網址」
- 網頁 `a01-loading-error.html`：一般內容
- Flutter：問題版只有視覺進度條，錯誤時顯示 WebView 自己的畫面。修正版載入中有 `liveRegion` 的狀態文字，載入超過一秒時完成後短暫顯示「網頁載入完成」；目前頂層載入的 http(s) 網址失敗時，用 Flutter 的錯誤畫面取代 WebView（標題、說明、重試按鈕）
- 內建伺服器支援 `__delay=<毫秒>` 查詢參數。外部來源沒有這個功能，按鈕改為一般重新載入並註明
- 預期：問題版載入中和失敗時報讀器都沒有提示；修正版都有，而且失敗畫面可以操作

### A02 JS 對話框
- 變體：問題版／修正版
- 網頁 `a02-js-dialogs.html`：三個按鈕分別呼叫 `alert`、`confirm`、`prompt`，結果顯示在按鈕下方
- Flutter：問題版不註冊處理函式；修正版註冊三個，用 Flutter 對話框顯示
- 預期：問題版在 iOS 上按了沒有對話框，`confirm` 直接當作取消；Android 出現系統對話框。修正版兩個平台都是同樣的 Flutter 對話框

### A03 電話、信箱、外部連結
- 變體：問題版／修正版
- 網頁 `a03-links.html`：`tel:`、`mailto:`、一個外部網域連結（`target=_blank`）、一個 PDF 連結（觀察用）。連結文字不宣稱「另開視窗」
- Flutter：問題版不攔截導覽。修正版用 `onNavigationRequest`：非 http(s) 交給 `url_launcher` 外部開啟，失敗時用 SnackBar 說明原因；其他網域用 In-app browser 開
- 預期：問題版 `tel:` 在 Android 出現 WebView 的錯誤頁、`mailto:` 在 iOS 沒反應，外部網域在同一個 WebView 開啟。修正版會開撥號或郵件程式。模擬器沒有這些程式，要用實機

### A04 外層包裝
- 變體：`ExcludeSemantics`／`IgnorePointer`／無包裝（修正版）；網頁用 `b-content.html`
- 預期：`ExcludeSemantics` 版報讀器完全讀不到網頁。`IgnorePointer` 版明眼人點不了，報讀器是否還能操作需實機確認

### A05 被遮住或隱藏的 WebView
- 變體：遮罩（問題版）／遮罩加 `BlockSemantics`（修正 A）／不建立 WebView（修正 B）／`IndexedStack` 分頁（觀察）
- 版面：`Stack` 裡 WebView 上蓋一層不透明的「維護中」畫面和一個按鈕；網頁用 `b-content.html`
- 預期：問題版用滑動仍會讀到下層網頁；兩個修正版不會。`IndexedStack` 版預期隱藏分頁的網頁讀不到

### B01 疊在 WebView 上方的 Flutter 元件點不到
- 變體：問題版（TLHC＋疊加）／修正 A（Hybrid Composition）／修正 B（版面避開）
- 版面：`Stack` 裡 WebView 上面疊一個「回到頂端」浮動按鈕；修正 B 把按鈕移到 WebView 外的底部列。AppBar 另有「開啟對話框」和「開啟底部選單」
- 怎麼測：Android 開 TalkBack，用手指直接摸浮動按鈕，再用滑動找它。對話框和底部選單的按鈕也各摸一次。用 profile 或 release 建置測
- 預期：問題版摸不到、滑得到。修正 B 摸得到。修正 A 依 issue 應該摸得到，但有 release 版仍失敗的回報，以實機為準；代價是效能。iOS 只有一種模式，可當對照

### B02 焦點進出、觸摸探索與朗讀（觀察頁）
- 單一變體，網頁用 `b-content.html`（標題、連結、按鈕、長文、含多行輸入框的表單、一個 `aria-live` 區域）。工具列有「更新網頁的 aria-live 區域」按鈕
- 觀察清單：
  1. 從 AppBar 一路滑進網頁、滑到底、再滑回 AppBar
  2. 手指直接摸網頁內的元素
  3. 標題導覽能不能跨過 AppBar 和網頁
  4. 連續朗讀（TalkBack「從頂端開始閱讀」、VoiceOver 雙指下滑）能不能跨過邊界
  5. 點多行輸入框後焦點在哪
  6. 焦點停在 Flutter 的工具列按鈕上，按「更新網頁的 aria-live 區域」，有沒有念出來
  7. Android：App 開著時關掉再開 TalkBack，網頁還能不能聚焦
  8. 同樣的步驟在 debug 和 release 建置各做一次
- 繞過方式：問題嚴重的頁面改用 In-app browser（T02）；Android 切換顯示模式重測

### B03 WebView 放在可捲動容器裡
- 變體：問題版（`ListView` 內嵌固定高度的 WebView，上下各有 Flutter 內容）／修正版（`Column` 加 `Expanded`，由網頁自己捲動）
- 預期：問題版報讀器摸不到或捲不到網頁下半部；修正版正常

### B04 離開 WebView 頁後的焦點復原（對照）
- 變體：預設行為／用 `FocusSemanticEvent` 復原
- 版面：兩個按鈕，「開啟 WebView 頁」和「開啟純 Flutter 頁」，各開一個全螢幕頁面。復原版在頁面關閉、轉場動畫結束後，對剛才按的那個按鈕送 `FocusSemanticEvent`
- 怎麼測：兩個按鈕各開一次再返回，比較焦點落在哪
- 預期：預設行為依平台而異；兩種頁面的結果是否相同正是要觀察的。復原版焦點回到剛才的按鈕
- 註明：這不是 WebView 特有的問題；官方不建議濫用這個 API

### B05 外接鍵盤、Switch Access、Voice Access（觀察頁）
- 單一變體；版面：上方 Flutter 輸入框、中間 WebView（含表單）、下方 Flutter 按鈕
- 觀察清單：Tab 鍵能否進出網頁；先在 Flutter 輸入框打字再到網頁輸入框打字（#130652）；Switch Access 掃描是否涵蓋網頁；Voice Access／語音控制的編號是否涵蓋網頁

### T01 診斷對照表
- 網頁 `t01-diagnostics.html`：表格三欄「項目／網頁自己偵測／App 傳入」。項目有主題、根字級（實際像素）、`-apple-system-body` 的實際像素、減少動態、高對比、粗體、語系、是否在 App 內、User-Agent、約定版本與能力。設定改變時即時更新

### T02 改用 In-app browser
- 說明兩種做法的取捨（In-app browser 無法用 Bridge、無法傳 App 主題和語系、和 WebView 不共用 Cookie）。按鈕：用 In-app browser 開 `b-content.html`；用 WebView 開同一頁（B02）

## 8. 驗證方式與限制

| 層級 | 內容 | 誰做 |
|---|---|---|
| 單元測試 | URL 組合、Bridge 訊息解析、返回決策、導覽與錯誤判斷、內建伺服器、設定、目錄完整性、assets 與 web 同步、各版面的語意結構 | 自動（`flutter test`） |
| 網頁自我測試 | 參數解析與預設值、修正開關、主題與字級計算 | 自動（Node 或瀏覽器） |
| 靜態檢查與建置 | `flutter analyze`、Android 與 iOS 模擬器建置 | 自動 |
| 冒煙測試 | 在模擬器啟動，確認每一頁的每個變體都載入得到網頁 | 實作者 |
| 逐任務審查 | 每個任務完成後，由獨立代理對照設計文件和計畫審查該任務的改動；全部完成後再做一次整體審查 | 審查代理（使用者指定要做） |
| **實機檢查點** | 第一個完整切片（C01）完成後，確認內建伺服器、Bridge、報讀器能進入網頁 | **使用者**，在其餘頁面動工之前 |
| **報讀器行為** | 每一頁的問題版和修正版 | **使用者在實機上**，依 README 的清單，用 profile 或 release 建置 |

報讀器行為沒有辦法自動驗證：iOS 模擬器不能執行 VoiceOver，TalkBack 在模擬器上的行為也不等於實機。實作完成時只能宣稱「可建置、可啟動、邏輯測試通過」，不能宣稱「無障礙行為已驗證」。

## 9. 風險與未決事項

| 項目 | 狀況 | 處理 |
|---|---|---|
| 開發環境 | 還沒確認本機有沒有 Flutter、Xcode、Android SDK | 計畫第一步檢查；不符合就停下來問使用者 |
| Flutter 版本 | 需要 `sendAnnouncement` 和 `supportsAnnounceOf`，下限訂 3.41。`MediaQuery.reduceMotionOf` 要 3.50 才有，所以改從 `dart:ui` 的 `AccessibilityFeatures.reduceMotion` 讀 | 版本不足或 API 不存在就停下來，不自行換成已棄用的 API |
| 基準互相干擾 | 共用 WebView 的修正可能改變別頁問題版的樣子 | §5.2 列出的兩條規則；實機檢查點先驗證 |
| 幾個示範在實機上可能看不出差別 | C06 修正 C 在 Android、C08、C11、C04 在 iOS、B01 修正 A | 已標成需實機確認或觀察頁，預期文字照實寫 |
| iOS 上載入 `http://127.0.0.1` | Apple 文件自相矛盾 | 兩個 ATS 鍵都設；實機檢查點確認 |
| In-app browser 開內建網頁 | 查無來源 | 失敗時明確提示改用外部來源；實機檢查點確認 |
| 頁數 | 23 頁，實作量不小 | 計畫分階段，每個階段結束都是可以執行的 App |
