# 審查紀錄

這份檔案記錄每個任務的逐任務審查：誰審的、各等級有幾項發現、每一項怎麼處理（計畫「執行流程 → 逐任務審查」第 6 點）。

**沒有任何報讀器行為在實機上驗證過。** 下面寫的「通過」指的是自動檢查和程式碼審查，不代表 TalkBack 或 VoiceOver 的實際表現。

## 執行前掃描（Task 0 之後、Task 1 之前）

協調者在派出 Task 1 之前把計畫掃過一次，找任務之間、任務和設計文件之間對不上的地方。下表是找到的項目和當時的裁定。

**Task 2 以後的裁定還沒有用在任何已完成的任務上。** 接手的協調者可以沿用，也可以重新裁定。沿用時要寫進那個任務的派工說明，因為實作代理和審查代理只看得到計畫。

| 編號 | 相關任務 | 發現 | 裁定 |
|---|---|---|---|
| P1 | 4、5 | `HomePage` 預設的 `pageBuilder` 要開 `DemoPage`，但 `DemoPage` 到 Task 5 才建立，Task 5 的檔案清單也沒有 `home_page.dart` | Task 4 先用一個私有的暫時頁面；Task 5 把預設改成 `DemoPage(spec: spec)` 並刪掉暫時頁面 |
| P2 | 4、5、6 | `DemoScaffold` 的建構子有 `options`、`onOptionChanged`（Task 4），Task 6 卻寫「`DemoPage` 顯示選項」，沒說由誰畫下拉選單 | `DemoScaffold`（Task 4）依 `spec.options` 畫出有標籤的下拉選單；`DemoPage`（Task 5）持有狀態；Task 6 用在 C04 |
| P3 | 4 | `DemoScaffold` 各欄位的型別計畫沒寫 | `DemoSpec spec`、`DemoVariant variant`、`ValueChanged<String> onVariantChanged`（傳變體 id）、`String title`、`bool titleIsLiveRegion`、`Widget body`、`Map<String, String> options`、`void Function(String optionId, String value)? onOptionChanged`、`List<Widget> actions`、`Widget? statusLine` |
| P4 | 2 | Step 1 要把套件版本補進 `docs/ENVIRONMENT.md`，commit 指令卻只有 `git add flutter_app` | commit 時一併加入 `docs/ENVIRONMENT.md` |
| P5 | 3 | macOS 的 `.DS_Store` 可能被 rsync 複製，或讓 assets 同步測試失敗 | 同步腳本排除 `.DS_Store`；測試比對時忽略它 |
| P6 | 8 | Step 5 要改 `web/shared/a11y-app.js`（`zoom` 修正關閉時改 viewport），但這個檔案不在 Task 8 的檔案清單 | 允許，步驟文字已明說；改完後網頁自我測試要全過 |
| P7 | 4 | 計畫只有 `DemoPage` 的 AppBar 能進設定頁；Task 4 完成時目錄是空的，設定頁進不去 | `HomePage` 的 AppBar 也放一個「設定」按鈕 |
| P8 | 6、11 | 目錄測試要求 `expectProblem`、`expectFixed` 非空，但 T01、T02、B02、B05 只有一個變體 | 不算衝突；這幾頁照實寫要觀察什麼 |

掃描時也確認過：Task 1 的 24 條斷言和 `ALL PASS (24)` 的數量相符；Task 11 的頁數 11＋5＋5＋2 等於 23；計畫指定的 Flutter 與外掛 API 在當時那台電腦安裝的版本裡都存在（清單在 `docs/ENVIRONMENT.md`）。

## Task 1：網頁核心

| 項目 | 內容 |
|---|---|
| 實作 | 全新子代理，Fable 5.2、xhigh。commit `edcc026`、`2ad5cfb` |
| 審查 | 獨立代理，Opus 5.5、high。只拿到設計文件、計畫與任務編號、commit 範圍 `0145063..2ad5cfb` |
| 審查結論 | 規格符合：是。品質：通過 |
| 發現數 | 必修 0、應修 3、可之後再做 5 |
| 修正 | 同一個實作代理。commit `b21ad56`、`450a7a2`、`cd6272f` |
| 複查 | 同一個審查代理，範圍 `230dab7..cd6272f`。三項要求修正的都已解決，沒有新問題，通過 |

### 每一項發現與處理

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 1 | 應修 | `web/test/run.mjs`、`web/test/index.html`：一條斷言都沒跑到時，兩個執行器都回報通過 | 重現：空的 `tests.js` 印出 `ALL PASS (0)`、exit 0 | 採納。`b21ad56`：0 條斷言時回報 `FAIL`，Node 的 exit code 為 1 |
| 2 | 應修 | 計畫把「自動送 `ready`」綁在 `arrival` 修正上，所以 C06 問題版不握手：App 不會重送設定，也拿不到網頁標題與 `caps`。這些不是 C06 要示範的，牴觸設計文件 §5.2 | 屬實（當時的 `a11y-app.js` 在兩處用 `arrival` 判斷）。這會改到計畫明訂的約定行為，所以交給規劃 session 裁定 | 規劃 session 裁定：`ready` 是握手，一律送；`arrival` 只控制網頁內換頁的回報。`450a7a2` 照做，並把 `reportRoute` 的判斷抽成純函式 `A11yCore.routeReportAction`，補上八種組合的斷言。計畫與設計文件的文字在 `230dab7` 更新 |
| 3 | 應修 | 不在 App 內時，計畫寫 `reportRoute` 一律把標題寫進 `aria-live` 區域；實作在「網頁移焦點」啟用時不寫。審查代理認為實作比較符合設計文件 §6.4 | 同意：照計畫字面做，同一個標題會因為焦點和 `aria-live` 各念一次 | 程式不改。規劃 session 定案以實作為準，計畫文字在 `230dab7` 更新 |
| 4 | 可之後再做 | `window.a11yApp` 的執行期部分沒有自動測試，只有 `A11yCore` 有 | 屬實。計畫沒有要求 | 暫不處理，留給整體審查判斷要不要補 |
| 5 | 可之後再做 | `caps` 的意思是「沒被關掉」，不是「這一頁有實作」，容易被誤讀 | 屬實（例如共用內容頁的 `caps` 含 `formErrors`） | 留給 Task 6（T01 頁面的用語）和 Task 12（`CONTRACT.md`）寫清楚 |
| 6 | 可之後再做 | `b-content.html` 的三個頁內連結會增加瀏覽紀錄；Task 7 的返回同步上線後，按返回會先在頁內錨點之間退 | 屬實，這是正確的網頁行為 | 頁面維持單純的寫法。用到這一頁的示範（Task 10、11）在「怎麼測」註明；整體審查時再看一次 |
| 7 | 可之後再做 | 「回上一頁」連結實際連到目錄頁，連結文字和去處不完全一致 | 屬實 | 不採納。設計文件 §7 C05 指定這個名稱，而且在 App 內這個連結是隱藏的 |
| 8 | 可之後再做 | `overflow-wrap: anywhere` 在 iOS Safari 15.4 以前不支援，專案下限是 iOS 13 | 寫法屬實；舊版 iOS 上的實際效果沒有機器可測 | 採納。`cd6272f` 在前面加一行 `overflow-wrap: break-word` 當備援 |

### 實作時對計畫文字的詮釋（已接受）

- 問題版／修正版的切換連結只在該頁有宣告修正（`data-fixes` 不是空的）時顯示。兩版完全相同的頁面顯示切換連結會誤導人。
- `A11yCore` 比計畫多了六個成員：`FIX_NAMES`、`parseFixList`、`enabledFixes`、`normalizeSettings`、`buildSearch`、`routeReportAction`。計畫列的六個成員名稱與簽章沒有變。
- 網頁自我測試現在是 68 條，不是計畫寫的 24 條。計畫的 24 條逐字保留在 `tests.js` 前段。

### 協調者自己做的查證

- `node web/test/run.mjs`：實作完成後 `ALL PASS (60)`，修正後 `ALL PASS (68)`，exit 0。
- 計畫 Step 1 的 24 條斷言和 `tests.js` 前段逐行比對，完全相同。
- 讀過這個任務的全部檔案與修正的 diff。
- 桌面瀏覽器（系統主題模擬成淺色）：`?theme=dark&textScale=1.5` 得到深色主題與 150% 根字級；加上 `embedded=1` 後 header 隱藏、第一個可見標題是 `<h2>`；不合法的參數回到預設或被限制在範圍內；測試頁標題是 `PASS`。
- 無頭 Chrome、暫存頁加假的 `A11yBridge`（暫存頁不在版控內）：問題版在 App 內有送 `ready`，`caps` 不含 `arrival` 與 `routeFocus`，不送 `routeChanged`；修正版在 App 內送 `routeChanged`；不在 App 內時只有關掉移焦點才寫 `aria-live`。

### 驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | `A11yCore` 的純函式（68 條斷言，Node 與瀏覽器跑同一份） |
| 桌面瀏覽器上看過 | `window.a11yApp` 的執行期行為、header 隱藏、主題與字級、切換連結、`ready` 與 `routeChanged` 的內容。用的是桌面版 Chromium 和假的 Bridge，不是 WebView |
| 未驗證 | 所有報讀器行為；真正的 Android WebView、WKWebView 與真正的 `A11yBridge`；iOS 13–15 的舊版瀏覽器；bfcache 的 `pageshow` 在 WebView 裡會不會觸發 |

### 不屬於 Task 1 審查範圍的 commit

| commit | 來源 | 內容 |
|---|---|---|
| `0145063` | 規劃 session，使用者確認 | 計畫改成逐任務指定實作與審查的模型 |
| `230dab7` | 規劃 session 的裁定，由協調者代為修改 | 計畫 Task 1 的 Interfaces 兩條、設計文件 §7 C06 一行，改成和上表第 2、3 項的裁定一致 |

### 留給後續任務的事項

- 呼叫 `reportRoute` 的頁面在換畫面後要自己把焦點移到新標題（除非該頁把 `routeFocus` 關掉）。沒有移焦點的話，在一般瀏覽器裡換畫面不會被念出來。審查 C06、C07 時要檢查。
- `reportRoute` 由核心依 `arrival` 把關，各頁可以無條件呼叫。`setBackState`、`requestClose`、`postToApp` 不看修正開關，要由各頁用 `a11yApp.fixEnabled()` 判斷。
- 核心不處理 `lang` 修正，由 C04 自己決定內容與 `<html lang>`。
- `base.css` 的 `:root` 設了 `color-scheme: light`，深色主題時才切成 `dark`。Android WebView 的自動調暗會不會受影響，要在 C02 的實機測試確認。
- 計畫 Task 1 Step 4 和 Task 12 Step 4 的預期輸出寫 `ALL PASS (24)`，現在是 68 條，之後還會增加。以「全部通過，而且計畫的 24 條逐字存在」為準。

## 換電腦後的接手（2026-11-21）

Task 2 起在第二台電腦上做，協調者是新的 session，依 `docs/HANDOFF.md` 接手。

- **執行前掃描的裁定 P1 到 P8 全部沿用**，用到的任務會寫進派工說明。
- **Task 0 在這台重做**（commit `846f742`，沒有可審查的產出，不送審）。接手時 Flutter 的全域設定指向一個不存在的 Android Studio，`flutter doctor` 和 `flutter create` 都失敗。使用者同意後改了兩個 Flutter 設定，細節在 `docs/ENVIRONMENT.md`。兩個平台都用拋棄式專案建置成功，Android 模擬器可以開機並執行 APK。
- **額度門檻：** Task 2 開始前每週 Fable 額度剩 9%，低於計畫訂的 10%。使用者決定這一次放寬門檻、直接開始，模型與強度不降。
- **這台多做的檢查：** 每個任務 commit 前，實作代理除了計畫列的驗證，還要跑 `flutter build apk --debug` 和 `flutter build ios --simulator --debug`；協調者查證時也重跑。依據是 Global Constraints 的「App 可建置」和交接文件要求的 Android 建置驗證。

## Task 2：Flutter 專案與純 Dart 約定層

| 項目 | 內容 |
|---|---|
| 實作 | 全新子代理，Opus 5.5、high。commit `6cf7c4a` |
| 審查 | 獨立代理，Fable 5.2、high。拿到設計文件、計畫與任務編號、commit 範圍 `846f742..6cf7c4a`，以及下面「派工時補的決定」。沒有拿到實作者的報告 |
| 審查結論 | 規格符合：是。品質：通過 |
| 發現數 | 必修 0、應修 0、可之後再做 2 |
| 修正與複查 | 沒有需要修正的項目，不需要複查 |

### 派工時協調者補的決定

| 決定 | 理由 |
|---|---|
| 刪掉範本的計數器後，`lib/main.dart` 留一個最小的暫時畫面 | 計畫只說刪掉計數器；Task 4 會整個改寫 `main.dart` |
| commit 一併加入 `docs/ENVIRONMENT.md` | 沿用 P4 |
| `ios/Podfile`、`ios/Podfile.lock` 納入版控 | 這台的 Flutter 設定關掉了 Swift Package Manager，iOS 外掛走 CocoaPods。在啟用 SPM 的電腦上建置時，Flutter 可能會自動修改 Xcode 專案，屆時再處理 |
| 範本產生的其他檔案維持原樣 | 計畫沒有要求修改 |

### 每一項發現與處理

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 1 | 可之後再做 | `buildDemoUri` 和 `isTrustedPage` 對「base 的路徑有沒有結尾斜線」的前提不一致：`isTrustedPage` 接受沒有結尾斜線的 base，`buildDemoUri` 遇到同樣的 base 會丟掉最後一段路徑 | 屬實（`web_contract.dart` 用 `base.resolve(webPath)`）。實作者的報告也獨立提到同一點。計畫裡 base 只來自內建伺服器的 `baseUri` 和 Task 4 的 `parseExternalBase`，兩者都以 `/` 結尾，照計畫走不到這個輸入 | 程式暫不改。Task 4 的派工說明會寫明 `AppScope.webBase` 一律以 `/` 結尾；整體審查時判斷要不要在 `buildDemoUri` 裡補上 |
| 2 | 可之後再做 | 訊息裡的字串會截到 200 字，但清單（`actions`、`caps`）的元素個數沒有上限，`actions` 是空清單也會被接受 | 屬實。計畫只規定字串截斷。訊息只在頂層網址屬於自家網域時才處理 | 留給 Task 9：實作原生對話框時決定 `actions` 個數的上下限，寫進那個任務的派工說明 |

實作者的報告另外提到 `normalizeTextScale(NaN)` 會丟例外。協調者用一個暫時的測試實際執行（跑完已刪除，沒有進版控）：**不會丟例外**，NaN 和正無限大都回傳 3.0，負無限大回傳 0.8。不需要處理。

### 實作時對計畫文字的詮釋（已接受）

- 可省略的欄位沒帶或是 null 時用預設值；有帶但型別不對（例如 `"contract":"1"`）時，整則訊息回傳 null。
- 200 字的截斷以 Unicode code point 計算，不會把一個字切成兩半；清單裡的每個字串也會截斷。全是表情符號的字串截斷後 `.length` 會是 400。計畫的斷言 `long.title.length == 200` 逐字通過。
- `updateSettingsScript` 的值用 JSON 原生型別（數字、布林），和網頁端 `normalizeSettings` 的檢查方式一致。

### 協調者自己做的查證

- 讀過三個原始檔的全文。用腳本把計畫 Step 2 的 52 行斷言和三個測試檔比對，全部逐字存在。
- 重跑 `flutter analyze`（零問題）、`flutter test`（28 個全過）、`node web/test/run.mjs`（`ALL PASS (68)`）。
- 重跑 `flutter build apk --debug` 和 `flutter build ios --simulator --debug`，都成功。
- 把建置出來的 App 裝進 Android 模擬器（`Pixel_4_API_32`）和 iOS 模擬器（iPhone 17、iOS 27.0）並啟動：兩邊行程都存在，Android 的 logcat 沒有 `FATAL EXCEPTION` 或 Flutter 錯誤。這時 App 只有一個暫時畫面，沒有 WebView。

審查代理另外做的查證（摘自它的報告）：用 `git archive` 匯出 commit，在 repo 外重新建置兩個平台都成功，建置後納入版控的檔案沒有變動；把 `buildDemoUri` 產生的網址交給網頁端的 `A11yCore.parseParams` 解析，結果正確；`jsCall` 的輸出在 Node 裡執行，含引號、換行、`</script>` 的引數都正確送達；壞掉的訊息（非 JSON、型別不對、超長、極深的巢狀）都回傳 null、不丟例外；`isTrustedPage` 擋得住 `data:`、`blob:`、不同埠、`..` 路徑、`127.0.0.1:8123@evil.com` 這類網址。

### 驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | 約定層的純函式（28 個測試）；網頁自我測試 68 條；`flutter analyze` |
| 建置與模擬器 | Android debug APK 與 iOS 模擬器 debug 建置成功；暫時畫面在兩個模擬器上啟動得起來 |
| 未驗證 | 所有報讀器行為；`runJavaScript` 在真正的 Android WebView 與 WKWebView 上的行為（Task 5 才有 WebView）；release 與 profile 建置；實機上的一切 |

### 留給後續任務的事項

- Task 4：`AppScope.webBase` 一律以 `/` 結尾（上表第 1 項）。
- Task 9：決定 `OpenNativeDialogMessage.actions` 的個數上下限（上表第 2 項）。
- 整體審查：判斷 `buildDemoUri` 要不要自己處理沒有結尾斜線的 base。

## Task 3：內建伺服器、assets 同步、平台設定

| 項目 | 內容 |
|---|---|
| 實作 | 全新子代理，Opus 5.5、high。commit `91fddb5`、`9b8b5d5`（後者是實作者自我檢查時發現 `normalizePath('/%ff')` 會丟例外而追加的修正） |
| 審查 | 獨立代理，Fable 5.2、high。拿到設計文件、計畫與任務編號、commit 範圍 `acbd067..9b8b5d5`，以及下面「派工時補的決定」。沒有拿到實作者的報告 |
| 審查結論 | 規格符合：是。品質：通過 |
| 發現數 | 必修 0、應修 1、可之後再做 3 |
| 修正 | 同一個實作代理。commit `b2f5ab5` |
| 複查 | 同一個審查代理，範圍 `9b8b5d5..b2f5ab5`。四項都已解決，修正通過；另外指出 1 項可之後再做的測試缺口 |

### 派工時協調者補的決定

| 決定 | 理由 |
|---|---|
| 同步腳本排除 `.DS_Store`，assets 同步測試比對時也忽略它 | 沿用 P5 |
| `tool/sync_web.sh` 要有執行權限，從其他目錄執行也要正確或明確報錯 | 腳本用了 `--delete`，路徑錯了會刪錯東西 |
| `LocalWebServer.baseUri` 一律以 `/` 結尾 | Task 2 審查的第 1 項 |
| 新的 intent 加進範本既有的 `<queries>` 區塊 | 範本已經有一個 `<queries>` |
| 三處明文 HTTP 設定都要有「僅供示範，正式專案不可照抄」的註解 | Global Constraints |
| 不在模擬器上執行 App；實作者改看合併後的 manifest 與建置後的 `Info.plist` | `main.dart` 到 Task 4 才啟動伺服器 |

### 每一項發現與處理

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 1 | 應修 | 查詢字串含「合法 hex 但不是合法 UTF-8」的 percent-encoding（例如 `?x=%ff`）時，伺服器回 500 而不是照常給檔案 | 讀程式屬實：`request.uri.queryParameters` 解碼失敗的例外被外層的 `catch` 接住。審查者用原始 socket 實測過 | 採納。`b2f5ab5`：讀 `__delay` 失敗時當作沒帶，照常回 200；補了測試 |
| 2 | 可之後再做 | `normalizePath` 擋「解碼後含 `/`、`\`、NUL」的那一行沒有測試，刪掉它所有測試仍通過 | 屬實：測試檔裡沒有 `%2f`、`%5c`、`%00` 的斷言 | 採納。`b2f5ab5` 補三條斷言；複查時把三個條件各自拿掉，測試都會失敗 |
| 3 | 可之後再做 | `ensureRunning` 的探測把「任何 HTTP 回應」都當成自己還活著。原埠被別的 HTTP 伺服器佔走時會回傳舊網址 | 讀程式屬實。既有的「原埠被佔」測試用的是 `ServerSocket`，不是 HTTP 伺服器，所以沒測到 | 採納。這不符合計畫寫的「原埠被佔才換埠」，而且舊網址仍會被 `isTrustedPage` 當成自家網域。`b2f5ab5`：每個伺服器實例產生一個隨機值，放在每個回應的 `x-a11y-demo-server` 標頭，探測時比對；補了測試 |
| 4 | 可之後再做 | `--exclude .DS_Store` 讓目的端既有的 `.DS_Store` 不受 `--delete` 影響，Finder 留在 `assets/web/` 的 `.DS_Store` 會被打包 | 屬實，這是 rsync 的既定行為 | 採納。`b2f5ab5`：rsync 之後刪掉目的端的 `.DS_Store` |
| 5 | 可之後再做（複查時提出） | 修正後探測依賴回應的標頭，但「伺服器正常時探測要成功」沒有測試釘住：把探測改成一律失敗，現有測試仍全過（原埠重啟後網址相同） | 屬實：那條測試只比對網址 | 目前的行為是對的（複查時實測過）。交給 Task 4 補一條測試：延遲請求進行中呼叫 `ensureRunning()`，該請求仍回 200。Task 4 正好是第一個呼叫 `ensureRunning()` 的任務 |

後三項標的是「可之後再做」，仍然在這一輪修掉：實作代理本來就要因為第 1 項被叫回來，改動都只有幾行，而使用者要求以正確度為優先。

### 實作時對計畫文字的詮釋（已接受）

- 路徑穿越的請求（`GET /../secret`）實際回 404 而不是 400。Dart 的 `HttpServer` 在交給處理函式之前就把 `..` 正規化掉了，所以 `normalizePath` 的 `..` 檢查是第二道防線。計畫的斷言是「400 或 404」，仍然符合。
- 只接受 GET，其他方法（包括 HEAD）回 405。停止後 `baseUri` 是 null。
- 建構子寫成 `LocalWebServer({required this._loader})`，對外的參數名稱仍是計畫指定的 `loader`。
- `ensureRunning` 的探測在最壞情況下（連得上但沒有回應）大約 6 秒才判定失效。

### 協調者自己做的查證

- 讀過 `local_web_server.dart` 全文、同步腳本、平台設定的 diff、`assets_sync_test.dart`，以及修正的 diff。計畫 Step 1 的 `expect` 都在測試檔裡。
- 重跑 `flutter analyze`（零問題）、`flutter test`（修正前 45 個、修正後 47 個，全過）、`node web/test/run.mjs`（`ALL PASS (68)`）；`assets/web` 與 `web/` 內容一致。
- 重跑兩個平台的建置，都成功。修正前的版本裝進 Android 模擬器與 iOS 模擬器後啟動成功，Android 的 logcat 沒有 `FATAL EXCEPTION` 或 Flutter 錯誤。

審查代理另外做的查證（摘自它的報告）：在 repo 外的複本建置兩個平台，確認合併後的 manifest 帶有 `INTERNET`、`networkSecurityConfig`、單一 `<queries>` 區塊內的四個 intent，APK 內有 `network_security_config.xml` 和 7 個網頁檔，iOS 的 `Info.plist` 帶有 ATS 兩個鍵、語系與區域網路說明；用原始 socket 送了 22 種壞掉的請求，loader 從未收到含 `..`、反斜線或開頭斜線的路徑；用戶端中途斷線、40 MB 大檔、連發 30 個 `start`／`stop`／`ensureRunning`、同時 8 個 `ensureRunning()` 都沒有未捕捉的錯誤；同步腳本從不同目錄、含空白的路徑執行都正確，路徑不對時報錯且不動到 assets。

### 驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | 伺服器的 HTTP 行為與靜態方法、assets 同步、`rootBundleLoader`（在測試環境下）；`flutter analyze`；網頁自我測試 68 條 |
| 建置與模擬器 | 兩個平台建置成功，原生設定確實進到建出來的 App；App 在兩個模擬器上啟動得起來（這時還沒有啟動伺服器） |
| 未驗證 | 伺服器在真正的 App 裡提供網頁（Task 4 起）；明文 HTTP 在真正的 Android WebView 與 WKWebView 裡是否放行；iOS 實際回收 socket 之後的恢復；In-app browser 連不連得到 `127.0.0.1`；`<queries>` 在實機上的效果；所有報讀器行為 |

### 留給後續任務的事項

- Task 4：補上表第 5 項的測試。
- 同步腳本的一個小毛病（複查時的附帶觀察，和修正無關）：目的端如果有一個來源已不存在、裡面只剩 `.DS_Store` 的目錄，第一次執行會印一行警告並留下空目錄，第二次執行才清掉。空目錄不進版控也不會被打包。留給整體審查判斷。
