# Flutter WebView 無障礙範例

一個 Flutter App 加一個配合的網頁專案，讓你**拿著手機、開著 TalkBack 或 VoiceOver 實際操作**，理解：

1. 即使 App 和網頁各自都做了無障礙，放進 WebView 之後哪些地方仍然會出問題。
2. 每個問題的「問題版」和「修正版」差在哪裡，修正要改在 App、網頁，還是兩邊。

每個問題一頁，可以在問題版和修正版之間切換，頁面上有「怎麼測」。修正版的程式碼可以當成參考實作，搬回正式專案。App 預設不需要網路，也不需要另外架伺服器。

> **還沒有任何報讀器行為在實機上驗證過。** 這份專案裡的「通過」指的是自動檢查、程式碼審查和模擬器上的畫面，不代表 TalkBack 或 VoiceOver 的實際表現。

## 目前進度

計畫共 23 個示範頁，分 12 個任務實作。

| 項目 | 狀態 |
|---|---|
| 網頁核心、App 與網頁的約定層、內建伺服器、設定、首頁、共用頁框、DemoWebView | 完成，已通過逐任務審查 |
| 示範頁 | 1 / 23：C01 字體大小 |
| 實機檢查點 | **進行中**：確認內建網頁在實機載入得到、報讀器進得了網頁之後，才繼續做其餘頁面 |
| 文件 | 這份 README 是過渡版，完整版（23 頁的測試步驟與預期）在最後一個任務補齊；`docs/CONTRACT.md` 還沒寫 |

每個任務的審查結果與處理方式記在 [docs/REVIEW_LOG.md](docs/REVIEW_LOG.md)。

## 專案結構

```
a11y-webview-demo/
├── web/                    純 HTML/CSS/JS，沒有框架、沒有建置步驟、不載入外部資源
│   ├── index.html          瀏覽器單獨開啟時的目錄
│   ├── shared/a11y-app.js  App 與網頁約定的網頁端實作
│   ├── shared/base.css
│   ├── pages/              每個示範一頁
│   └── test/               網頁的自我測試（Node 和瀏覽器都能跑）
├── flutter_app/            範例 App
│   ├── assets/web/         web/ 的複本，由 tool/sync_web.sh 產生，納入版控
│   └── lib/
│       ├── contract/       URL 參數、Bridge 訊息、返回決策（純 Dart）
│       ├── server/         App 內建的網頁伺服器（127.0.0.1）
│       ├── settings/       網頁來源、App 主題、Android 顯示模式
│       ├── catalog/        每個示範頁的宣告
│       ├── webview/        DemoWebView：所有修正都打開的參考包裝
│       ├── widgets/        共用頁框、示範頁
│       └── pages/          首頁
└── docs/                   設計文件、實作計畫、環境紀錄、審查紀錄
```

## 環境需求

| 項目 | 需求 |
|---|---|
| Flutter | stable 3.41.0 以上（開發時用 3.47.5） |
| iOS | Xcode；iOS 13.0 以上的裝置或模擬器 |
| Android | Android SDK；Android 7.0（API 24）以上的裝置或模擬器 |
| Node.js | 選用，跑網頁的自我測試 |
| Python 3 | 選用，改用外部網頁來源時架伺服器 |

開發機實際的版本與設定記在 [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md)。

## 在模擬器上執行

```bash
cd flutter_app && flutter run
```

模擬器可以看畫面、切換變體、確認網頁載入得到，但**不能用來判斷報讀器行為**：iOS 模擬器不能執行 VoiceOver，TalkBack 在 Android 模擬器上的行為也不等於實機。

## 用報讀器在實機上測試

**一定要用 profile 或 release 建置。** debug 版在報讀器下很慢，行為也可能和正式版不同。

```bash
cd flutter_app && flutter run --profile -d <裝置代號>
```

裝置代號用 `flutter devices` 查。

**Android**

1. 手機開啟「開發人員選項」與「USB 偵錯」，用線接上電腦，在手機上允許偵錯。
2. `flutter devices` 看得到手機後，用上面的指令安裝。

**iOS**

1. 手機開啟「開發者模式」（設定 → 隱私權與安全性），用線接上 Mac。
2. 用 Xcode 開 `flutter_app/ios/Runner.xcworkspace`，在 Runner 的 Signing & Capabilities 選你的 Team。bundle ID（`com.example.a11ydemo.a11yWebviewDemo`）不能用時，在 Xcode 裡改一個自己的。
3. 第一次安裝後，到手機的「設定 → 一般 → VPN 與裝置管理」信任你的開發者憑證。

## 怎麼用

- **首頁**依類別分區列出示範頁，每列顯示代號、標題、修正方、可信度、平台。AppBar 有「設定」。
- **進入一頁後：**
  - 上方是變體選擇（例如「問題版」「修正版」「只改 App」），切換時 WebView 會整個重建。
  - 下面一行是標示：修正在哪一邊、可信度、平台。
  - 「怎麼測」可以展開，內容有前置、步驟、問題版與修正版的預期、依據、要看哪些程式檔。
  - AppBar 的按鈕：「用 In-app browser 開啟本頁」「重新載入」「設定」。
- **設定頁：**
  - 網頁來源：內建或外部（見下一節）。
  - App 主題：跟隨系統、淺色、深色。
  - Android 顯示模式：只在 Android 顯示。打開時用 Hybrid Composition，關閉時用預設的 TLHC。這是全域設定，每一頁都可以切換後重測。
- 開著報讀器時，建議每一頁先讀「怎麼測」，照步驟分別試問題版和修正版。

## 改用外部網頁來源

App 預設從內建伺服器（`http://127.0.0.1:<隨機埠>/`）載入網頁。想直接改網頁、不重建 App，可以自己架伺服器：

```bash
cd web && python3 -m http.server 8000
```

再到 App 的「設定 → 網頁來源」選「外部」，填網址：

| 在哪裡跑 App | 外部網址 |
|---|---|
| Android 模擬器 | `http://10.0.2.2:8000/` |
| iOS 模擬器 | `http://127.0.0.1:8000/` |
| 實機（和電腦在同一個 Wi-Fi） | `http://<電腦的區域網路 IP>:8000/`（iOS 實機能不能連，需實機確認） |

## 修改網頁之後

內建伺服器提供的是 `flutter_app/assets/web/` 裡的複本。改完 `web/` 要同步，否則 App 看到的還是舊的：

```bash
flutter_app/tool/sync_web.sh
```

`flutter test` 裡有一條測試會檢查兩邊是否一致。

## 自動檢查

```bash
cd flutter_app && flutter analyze && flutter test
```

```bash
node web/test/run.mjs
```

網頁的自我測試也可以用瀏覽器開 `web/test/index.html` 來跑（頁面標題會變成 `PASS` 或 `FAIL`）。

## 三種類別

| 類別 | 意思 | 網頁團隊需要參與嗎 |
|---|---|---|
| C 兩邊約定 | App 和網頁要約好參數、訊息和責任分工，缺一邊就不成立 | 要 |
| A App 單方處理 | 網頁本身沒問題，但放進 WebView 後要 App 接手處理，或 App 的包法出錯 | 不用 |
| B 交界處限制 | Flutter 嵌入原生 WebView 的機制造成的問題，有些能靠 App 的版面繞過，有些只能觀察 | 不用 |
| T 工具 | 幫助判斷問題的對照頁 | — |

可信度：「已查證」是官方文件或原始碼明確支持；「需實機確認」是來源互相矛盾、只有 issue 回報、從機制推論，或結果取決於報讀器本身；「觀察頁」是沒有可靠修法或正確做法因裝置而異，頁面提供觀察清單和繞過方式。

## 示範頁一覽

| 代號 | 標題 | 修正方 | 可信度 | 平台 | 狀態 |
|---|---|---|---|---|---|
| C01 | 字體大小 | 兩邊 | 已查證 | 兩個平台 | **已實作** |
| C02 | 深淺色主題 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 6） |
| C03 | 粗體、高對比、減少動態 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 6） |
| C04 | 語系 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 6） |
| C05 | 標題與重複導覽 | 兩邊 | 已查證 | 兩個平台 | 待實作（Task 7） |
| C06 | 頁面抵達：朗讀與焦點 | App 或網頁擇一 | 需實機確認 | 兩個平台 | 待實作（Task 7） |
| C07 | 返回、瀏覽紀錄與關閉 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 7） |
| C08 | 縮放 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 8） |
| C09 | 網頁叫出原生對話框 | 兩邊 | 需實機確認 | 兩個平台 | 待實作（Task 9） |
| C10 | 原生按鈕送出網頁表單 | App 或網頁擇一 | 需實機確認 | 兩個平台 | 待實作（Task 9） |
| C11 | 安全區域與鍵盤遮擋 | 兩邊 | 觀察頁 | 兩個平台 | 待實作（Task 9） |
| A01 | 載入中與錯誤 | App | 已查證 | 兩個平台 | 待實作（Task 8） |
| A02 | JS 對話框 | App | 已查證 | 兩個平台 | 待實作（Task 8） |
| A03 | 電話、信箱、外部連結 | App | 需實機確認 | 兩個平台 | 待實作（Task 8） |
| A04 | 外層包裝 | App | 需實機確認 | 兩個平台 | 待實作（Task 10） |
| A05 | 被遮住或隱藏的 WebView | App | 需實機確認 | 兩個平台 | 待實作（Task 10） |
| B01 | 疊在 WebView 上方的 Flutter 元件點不到 | App | 需實機確認 | 只有 Android | 待實作（Task 10） |
| B02 | 焦點進出、觸摸探索與朗讀 | — | 觀察頁 | 兩個平台 | 待實作（Task 11） |
| B03 | WebView 放在可捲動容器裡 | App | 需實機確認 | 兩個平台 | 待實作（Task 10） |
| B04 | 離開 WebView 頁後的焦點復原 | App | 需實機確認 | 兩個平台 | 待實作（Task 11） |
| B05 | 外接鍵盤、Switch Access、Voice Access | — | 觀察頁 | 兩個平台 | 待實作（Task 11） |
| T01 | 診斷對照表 | — | 已查證 | 兩個平台 | 待實作（Task 6） |
| T02 | 改用 In-app browser | — | 已查證 | 兩個平台 | 待實作（Task 11） |

每一頁的設計（變體、網頁與 App 在各變體的差異、預期）在[設計文件](docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md) §7。

### C01 字體大小

- **問題：** iOS 的網頁預設不跟系統字級；Android 會跟，但只在 WebView 建立時套用、之後不更新，而且 App 和網頁兩邊都放大時會放大兩次。
- **變體：**
  - 問題版：兩邊都不處理。網頁用 `px` 字級加固定高度的卡片。
  - 修正版：網頁負責放大。App 傳 `textScale`，Android 另外 `setTextZoom(100)` 關掉 WebView 自己的放大；網頁根字級跟著 `textScale`、全部用 `rem`、不固定高度。
  - 只改 App：App 負責放大（Android `setTextZoom`、iOS 注入 `-webkit-text-size-adjust`），網頁維持問題版的寫法。
- **怎麼測：** 把系統字級調到最大後進入這一頁，依序切換三個變體；再選一個變體，頁面開著時到系統設定改字級，回來看網頁有沒有跟著變。
- **預期：**
  - 問題版：iOS 網頁的字不變大。Android 字會變大但卡片文字被切掉，頁面開著時改字級網頁不更新。
  - 修正版：兩個平台都跟著變大、不破版，頁面開著時改字級也會更新。
  - 只改 App：字會變大，但卡片仍然破版，說明網頁還是得配合；iPad 上可能無效（需實機確認）。
- **模擬器上看過的結果**（不是報讀器行為）：Android（Android 12）和 iOS（iOS 27）三個變體都符合上面的預期，Android 修正版沒有被放大兩次。

## 已知限制

- **報讀器行為沒有自動驗證的方法**，所有頁面的無障礙表現都要在實機上用報讀器確認。
- **iOS 實機能不能載入 `http://127.0.0.1` 的內建網頁**還沒確認。Apple 文件對 iOS 17 以上 IP 位址的規則說法不一致，所以 `Info.plist` 把 `NSAllowsLocalNetworking` 和 `NSAllowsArbitraryLoadsInWebContent` 兩個都設了。
- **Android 的 In-app browser（Custom Tabs）能不能開內建網頁**還沒確認（模擬器的 Chrome 停在首次啟動畫面）。iOS 模擬器上 SFSafariViewController 開得了。
- **開發用的 Android 模擬器是 Android 12**，看不到 Android 14 以上才有的行為（非線性字級放大、高對比設定）。
- **明文 HTTP 與內建伺服器只供示範。** 內建伺服器綁在 `127.0.0.1`，同一台裝置上的其他 App 也連得到它；正式專案的網頁應該來自 HTTPS 網站，相關設定檔都標了「僅供示範，正式專案不可照抄」。
- **App 對網頁訊息的信任判斷有殘留風險**：自家頁面裡的跨網域 iframe 送的訊息無法分辨；判斷依賴模擬器上量到的回呼順序。詳見設計文件 §6.3。

## 文件

| 文件 | 內容 |
|---|---|
| [設計文件](docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md) | 目的、查證結果、23 頁的設計、App 與網頁的約定（§6） |
| [實作計畫](docs/superpowers/plans/2026-11-21-webview-a11y-demo.md) | 12 個任務的步驟、介面與測試 |
| [環境紀錄](docs/ENVIRONMENT.md) | 開發機的工具版本、模擬器、在模擬器上看到的結果、未驗證的項目 |
| [審查紀錄](docs/REVIEW_LOG.md) | 每個任務的審查發現與處理方式 |
| [交接說明](docs/HANDOFF.md) | 換電腦或換 session 接續執行時的說明 |
