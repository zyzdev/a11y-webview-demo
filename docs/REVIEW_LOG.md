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

## 模型改用 Opus（2026-11-21 17:20 起）

Task 4 的複查進行到一半時，每週 Fable 額度用完（21:00 重置）。使用者把協調者改成 Opus 5.5，並在詢問後選擇「全部改用 Opus」：實作、審查、複查都用 Opus，不等重置。這推翻了計畫「執行方式」的兩條規定：逐任務表裡的 Fable 角色，以及「實作和審查永遠用不同模型」。

協調者在這個決定下的做法：

| 做法 | 理由 |
|---|---|
| 強度照原表保留：原本 Fable xhigh 的角色改成 Opus xhigh，原本 Fable high 的審查改成 Opus high | 只換模型，不降強度 |
| 審查代理一律是全新代理、不拿實作者的報告，並明確要求以「找出錯誤」為目標、每個結論都實際執行驗證 | 實作和審查同一個模型，盲點容易重疊 |
| Task 4 的複查和 Task 5 的實作同時進行；審查代理一律在 `git archive` 匯出的複本上做，不碰工作目錄 | Task 4 沒有必修，依計畫可以開始下一個任務；複查發現的問題排在 Task 5 實作之後修 |
| Fable 重置後不自動切回原表 | 使用者沒有說只到重置為止；要切回時由使用者指示 |

從 Task 4 的複查起，下面每個任務的紀錄都會寫明實作與審查實際用的模型。

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

## Task 4：設定、目錄模型、首頁與共用頁框

| 項目 | 內容 |
|---|---|
| 實作 | 全新子代理，Opus 5.5、high。commit `6f493b6`、`ab5b849`（後者是實作者在模擬器上操作時發現的問題：輸入框失焦時改寫使用者打的字、頁面關閉後仍收到通知；並補了回到前景重啟伺服器的測試） |
| 審查 | 獨立代理，Fable 5.2、high。拿到設計文件、計畫與任務編號、commit 範圍 `cafcd5f..ab5b849`，以及下面「派工時補的決定」。沒有拿到實作者的報告 |
| 審查結論 | 規格符合：是。品質：通過 |
| 發現數 | 必修 0、應修 3、可之後再做 3 |
| 修正 | 同一個實作代理，三輪。commit `a4ca1d6`、`8441900`、`c9a1f31` |
| 複查 | 原本的 Fable 審查代理在複查途中遇到每週 Fable 額度用完而停止。之後依使用者的決定改用 Opus（見「模型改用 Opus」一節），由一個全新的 Opus 5.5、high 代理接手複查，三輪都由它複查。第一輪不通過（第 1 項沒解決、第 3 項沒修乾淨），第二輪通過但指出一個新的應修，第三輪通過 |

### 派工時協調者補的決定

| 決定 | 理由 |
|---|---|
| `HomePage` 預設的 `pageBuilder` 先用私有暫時頁面 | 沿用 P1，Task 5 換成 `DemoPage` |
| `DemoScaffold` 的欄位型別 | 沿用 P3 |
| 選項的下拉選單由 `DemoScaffold` 畫，狀態由呼叫端持有，並補元件測試 | 沿用 P2 |
| `HomePage` 的 AppBar 放「設定」按鈕 | 沿用 P7 |
| `AppScope.webBase` 一律以 `/` 結尾，要有測試或斷言 | Task 2 審查的第 1 項 |
| 目錄是空的時候首頁只有 AppBar | 計畫的測試只要求沒有資料的分區不顯示 |
| 補一條 Task 3 留下的測試：延遲請求進行中呼叫 `ensureRunning()`，回傳同一個網址、延遲請求仍回 200 | Task 3 複查的第 5 項 |
| 「Android 顯示模式」用 `defaultTargetPlatform` 判斷，並有測試 | 元件測試才能覆寫平台 |
| 內建伺服器啟動失敗時仍然 `runApp`，畫面上說明原因 | 不能白畫面 |
| 在兩個模擬器上確認首頁、設定頁、內建伺服器真的從 assets 提供網頁 | 這是第一個有畫面、也是第一個在 App 裡啟動伺服器的任務 |

### 每一項發現與處理

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 1 | 應修 | `DemoScaffold` 的 `statusLine` 沒有高度上限。字級 3 倍時 WebView 區域被擠到接近 0，小螢幕與橫向會溢出 | 讀程式屬實：控制區限制在一半高度，`statusLine` 在限制之外。觸發的字串是 Task 7 自己指定的狀態文字 | 採納。`a4ca1d6`：控制區與狀態列放進同一個最多佔一半高度的捲動區。實作者量到 WebView 區域在 390×844、字級 3 倍時從 25 變成 394；320×568 從溢出 233px 變成 256 |
| 2 | 應修 | 伺服器啟動失敗的說明在大字級時佔滿畫面。說明叫使用者去設定，但設定按鈕按不到 | 讀程式屬實：說明沒有高度上限、不能捲動 | 採納。`a4ca1d6`：說明最多佔約三分之一高度，超過時在說明裡捲動。實作者量到首頁高度從 0 變成 563，點得到「設定」 |
| 3 | 應修 | 外部網址接受埠號超出範圍（`10.0.2.2:80000`、`-1`）、host 含空白或全形字的輸入 | 屬實。這是計畫規則（只檢查 scheme 與 host 非空）的缺口，不是實作者偏離計畫 | 採納。`a4ca1d6`：有寫埠號時必須在 1–65535，host 含 `%` 或空白就拒絕。計畫原有的七條斷言都通過。`10.0.2.2:0` 也因此被拒絕 |
| 4 | 可之後再做 | 拒絕查詢字串與 `#` 片段的分支沒有測試 | 屬實 | 採納。`a4ca1d6` 補測試 |
| 5 | 可之後再做 | 打完網址不離開輸入框就點「外部」，網址還沒存，畫面顯示舊的位置 | 屬實（審查者用元件測試重現） | 採納。`a4ca1d6`：選「外部」時先存輸入框的內容，不改寫使用者打的字 |
| 6 | 可之後再做 | 一行註解把報讀器的念法寫成事實 | 屬實。Global Constraints 不允許宣稱報讀器行為已驗證 | 採納。`a4ca1d6`：這個任務的註解都改成「預期……（需實機確認）」 |

後三項標的是「可之後再做」，仍然在這一輪修掉：實作代理本來就要因為前三項被叫回來，改動都很小，而使用者要求以正確度為優先。

### 複查與後續修正

**第一輪複查（範圍 `ab5b849..a4ca1d6`）：不通過。** 第 2、4、5、6 項已解決。

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 7 | 必修 | 第 1 項沒解決：WebView 區域確實拿到一半高度、不溢出，但狀態列被放在捲動區的最後。大字級或展開「怎麼測」時完全看不到，語意節點被標成隱藏，比修正前更糟。實作者的新測試先捲過去才檢查，所以沒抓到 | 讀程式屬實：狀態列是捲動區裡最後一個子元件 | 採納。`8441900`：狀態列移到控制區下方、WebView 正上方，最多佔上半部的一半、在自己裡面捲動；控制區在剩下的空間裡捲動。測試改成不捲動直接檢查，涵蓋七種畫面與字級組合，以及「狀態列先沒有、之後才出現」 |
| 8 | 應修 | 第 3 項沒修乾淨：埠號大到超過整數範圍（`http://h:99999999999999999999/`）時丟例外而不是回傳 null；在設定頁會讓「外部」切不過去 | 複查者實際執行重現 | 採納。`8441900`：讀埠號失敗時回傳 null，補測試 |
| 9 | 可之後再做 | 錯誤說明在 320×568、預設字級時就需要捲動，行動平台沒有捲軸提示 | 判斷 | 暫不處理，留給整體審查 |

**第二輪複查（範圍 `72d62ad..8441900`）：通過**，兩項都已解決。複查者把上一輪的版面換回去跑新測試，14 條全部失敗，證明新測試確實抓得到原本的問題；被刪掉的那組舊測試，條件與斷言都保留在新測試裡。修正後大字級時狀態列不用捲動就看得到 61.5–192.5 像素，語意節點不是隱藏。另外指出一個這次帶進來的問題：

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 10 | 應修 | 有狀態列時畫面上有兩個捲動區，兩個都接到同一個 `PrimaryScrollController`，外接實體鍵盤按 PageDown 會丟例外。設計文件的 B05 是外接鍵盤觀察頁，會實際碰到 | 複查者在兩個平台的元件測試重現 | 採納。`c9a1f31`：狀態列那層加 `primary: false`；補 Android、iOS 各一條按 PageDown 的測試 |

**第三輪複查（範圍 `8441900..c9a1f31`）：通過。** 有狀態列時只掛一個捲動位置，按 PageDown 捲動的是控制區；拿掉這一行時新測試會失敗。複查者附帶一個觀察：新測試只檢查不丟例外，沒有斷言控制區真的捲動了（目前的行為是對的），列為可之後再做。

### 實作時和計畫寫法不同的地方（審查者判斷不影響後續任務）

- `DemoWebController` 的狀態欄位寫成 getter／setter，值有變才通知畫面重建；頁面關閉後照常賦值、不通知。名稱、型別、預設值和計畫相同，讀寫語法也相同，後續任務的測試仍可繼承它並覆寫 `runJavaScript`。原因是 `notifyListeners` 是 `@protected`，Task 5 的 `DemoWebView` 從外面改狀態時無法合法通知。
- `AppScope` 多了必填的 `builtInBase` 建構參數：內建伺服器從沒啟動成功時用 `http://127.0.0.1/` 當替代網址，示範頁會載入失敗，App 不會當掉。計畫沒有規定 `AppScope` 的建構子。
- 純新增的成員：列舉的 `label`、`DemoSpec` 的 `code` 與 `badgeLine`、頂層函式 `resolveWebBase`。

### 協調者自己做的查證

- 讀過 `demo_web_controller.dart`、`demo_webview_config.dart`、`app.dart`、`main.dart` 全文，以及其他檔案的類別與建構子簽章；計畫 Step 1 的斷言都在測試檔裡。讀過修正的 diff。
- 重跑 `flutter analyze`（零問題）、`flutter test`（修正前 97 個、修正後 106 個，全過）、`node web/test/run.mjs`（`ALL PASS (68)`）；`assets/web` 與 `web/` 一致。
- 修正前與修正後各重跑一次兩個平台的建置，都成功；都裝進 Android 模擬器與 iOS 模擬器後啟動成功，Android 的 logcat 沒有 `FATAL EXCEPTION` 或 Flutter 錯誤。
- 第二、三輪修正：讀過 diff（只動到設定與頁框的檔案，沒有碰 Task 5 的檔案；第三輪沒有刪任何測試行），各重跑一次 `flutter analyze`（零問題）、`flutter test`（159、161 個全過，含 Task 5 的測試）、`node web/test/run.mjs`（`ALL PASS (68)`）與兩個平台的建置（都成功）。這兩輪沒有開模擬器，因為 Task 5 的審查代理可能正在使用。

實作代理與審查代理各自在兩個模擬器上做過的確認（摘自它們的報告）：首頁有 AppBar 與「設定」按鈕；設定頁進得去，iOS 上沒有「Android 顯示模式」、Android 上有；切換深色主題畫面跟著變；外部網址打錯會顯示錯誤文字（iOS 上的輸入流程審查者無法操作，只有元件測試）；從 Mac 連進 App 裡的內建伺服器，`/`、`/shared/a11y-app.js`、`/shared/base.css`、`/pages/b-content.html` 等都回 200、content-type 正確、和 `web/` 位元組相同，`/pages/missing.html` 回 404。審查者另外在 iOS 模擬器把 App 放到背景 20 秒再回前景，同一個埠回 200；這只說明模擬器上回前景後原埠可用，不代表驗證了 iOS 真的回收 socket 之後的恢復。

審查者也用變異測試確認測試真的釘住行為：把 AppBar 標題的 liveRegion 寫死、把首頁分區標題的 header 拿掉、把伺服器探測改成一律失敗，各自都有測試失敗。並用 Flutter 內建的點擊目標大小、標籤、文字對比檢查，首頁、設定頁、頁框在淺色與深色下都通過。

### 驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | 設定的存取與外部網址解析、目錄結構檢查（目前目錄是空的）、首頁與頁框的語意結構（標題的 header、liveRegion、變體的選取狀態、下拉選單的標籤）、大字級下的版面高度、伺服器啟動失敗時的畫面、回到前景時重啟伺服器 |
| 在模擬器上看過 | 兩個平台的首頁與設定頁；內建伺服器在 App 裡啟動，從 assets 提供正確的網頁 |
| 未驗證 | 所有報讀器行為（標題、liveRegion、變體選取、下拉選單、單選群組實際怎麼念）；實機上大字級的版面（只在元件測試裡量過；Android 模擬器是 API 32，看不到 Android 14 以上的非線性字級）；iOS 真的回收 socket 之後的恢復 |

### 留給後續任務的事項（審查者對照 Task 5–11 的用法後提出）

- Task 5、6：`DemoScaffold` 在 `options` 沒有該項時顯示第一個值，但 `configFor` 拿到的是呼叫端的 Map。`DemoPage` 要先把每個選項填成第一個值，否則 C04 修正版傳出去的會是 App 的語系，和畫面上顯示的不同。
- Task 5：`DemoWebController` 的 setter 會立刻通知畫面重建，`DemoWebView` 不可以在 `initState` 或 build 期間設定狀態欄位。
- Task 5：控制器沒有重設狀態的方法。切換變體重建 WebView 時，不能讓上一個變體的標題、返回狀態、載入失敗狀態留下來，也不能讓舊 WebView 晚到的回呼寫進新的狀態。
- Task 8：計畫要 `loadUri` 記下目標網址，所以一定要改 `demo_web_controller.dart`，而這個檔案不在 Task 8 的檔案清單裡。協調者裁定允許。

## Task 5：DemoWebView 與第一個完整切片（C01 字體大小）

| 項目 | 內容 |
|---|---|
| 實作 | 全新子代理，**Opus 5.5、xhigh**（計畫原訂 Fable 5.2 xhigh，依使用者「全部改用 Opus」的決定更換）。commit `72d62ad` |
| 審查 | 全新代理，**Opus 5.5、high**（計畫原訂 Opus 5.5 high，但實作者也是 Opus）。拿到設計文件、計畫與任務編號、commit 範圍 `a2a42b3..72d62ad`，以及下面「派工時補的決定」；沒有拿到實作者的報告；被要求以找錯為目標、在 `git archive` 匯出的複本上做，並可以在兩個模擬器上實測 |
| 審查結論 | 第一次：**規格符合：否。品質：不通過**。修正後兩輪複查：第一輪找到一條新的繞過路徑（必修），第二輪通過 |
| 發現數 | 第一次：必修 2、應修 1、可之後再做 2。複查新增：必修 1、可之後再做 1 |
| 修正 | 同一個實作代理。commit `1ff7891`、`6e65e2e`、`b5b27a6`。設計文件與計畫的修改：`de0e874`、`973c3c0`、`afd88e1`、`7173c1c`、`470ad23` |
| 狀態 | **通過。** 接下來是計畫的實機檢查點，等使用者確認 |

### 派工時協調者補的決定

| 決定 | 理由 |
|---|---|
| `HomePage` 的預設 `pageBuilder` 換成 `DemoPage`，刪掉暫時頁面（允許改 `home_page.dart`） | 沿用 P1 |
| `DemoPage` 先把每個選項填成第一個值，同一個 Map 交給頁框與 `configFor` | Task 4 審查留下的事項 |
| `DemoWebView` 不可在 `initState`、`didUpdateWidget`、build 期間設定控制器的狀態 | 同上 |
| 切換變體、選項或顯示模式時換一個新的控制器，舊 WebView 晚到的回呼不能寫進新狀態 | 同上 |
| 守住基準原則與朗讀原則；返回、載入與錯誤、JS 對話框、外部連結、縮放留給 Task 7、8 | 計畫 |
| `c01-text-scale.html` 照範本頁，問題版與修正版只差 `textScale` | 基準原則 |
| C01 的「怎麼測」依 §7 寫齊，`docs/ENVIRONMENT.md` 記下 In-app browser 與模擬器的結果 | 計畫 |

### 每一項發現與處理

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 1 | 必修 | **iOS 上信任判斷在新頁面換上之前就切換。** iOS 的 `onPageStarted`（對應 WebKit 的 `didStartProvisionalNavigation`）與 `onUrlChange` 在新頁面還沒換上時就觸發，App 立刻用新網址判斷信任。結果：不受信任的頁面導向自家網頁、而回應還沒回來的那段時間，舊頁面送的訊息被當成自家訊息處理（違反 §6.3）；反方向時，還在畫面上的自家頁面送的訊息被丟掉。Task 7 以後 `close`、`openNativeDialog`、`backState` 都走同一條路 | 讀審查者在 iOS 模擬器的紀錄屬實：外部頁面導向延遲 7 秒的自家網頁後，外部頁面送的 24 則假 `ready` 都被接受，AppBar 標題被改掉。Android 同樣情境 0 則被接受（Android 的 `onPageStarted` 在新頁面換上時才觸發）。用 `onPageStarted` 追蹤頂層網址是計畫指定的做法 | 待使用者決定 |
| 2 | 必修 | **iOS 上「網頁負責」的自家頁面被注入 `-webkit-text-size-adjust`，字被放大兩次，而且不會清掉。** 導向外部網域一開始，策略就改成「App 負責」，放大設定被注入到還在畫面上的自家頁面；導覽沒有換成頁（204、取消、`tel:`）或按返回從 bfcache 還原時，自家頁面就停在放大兩次的狀態 | 屬實。審查者的頁面回報：自家頁面的字從 21.6px 變成 29.16px（16 × 1.35 × 1.35）。另外，計畫寫的是 iOS 在 `onPageFinished` 之後才注入，實作在 `onPageStarted` 時就注入，這一點是實作偏離計畫 | 待使用者決定（和第 1 項同一個根源） |
| 3 | 應修 | iOS 上沒換成頁的導覽（204、取消）也會觸發 `onPageStarted`，把「這一頁送過 `ready`」重設成否；畫面上還是同一頁、不會再送 `ready`，之後字級或主題改變就不會再通知網頁。這種導覽之後也沒有 `onPageFinished`，`loading` 會停在 true（Task 8 的 A01 會用到） | 沒有 `onPageFinished` 是審查者看 log 確認的；設定不再送出是從程式推論的 | 待使用者決定（同一個根源） |
| 4 | 可之後再做 | 自家頁面裡的跨網域 iframe 送的訊息會被接受。這和 §6.3「以頂層網址判斷」一致（外掛的訊息不帶來源 frame），但這是殘留風險 | 審查者在 iOS 實測 | 寫進 Task 12 的 `CONTRACT.md` |
| 5 | 可之後再做 | 「只改 App」的預期沒有寫「頁面開著時改字級也會更新」 | 審查者在兩個平台看到它確實會更新 | 和修正一起補 |

審查者另外指出測試的缺口：測試用的假平台不是 Android 或 iOS 的控制器，所以字級策略和網址變化的連動完全沒有測試。

### 修法的決定與過程

使用者在兩個選項中選了方案 A：把頂層網址分成「已換上」與「載入中」，載入完成才算換上；載入中時新舊網址都屬於自家網域才處理訊息；新頁面是自家、舊頁面不是時，載入完成後 App 呼叫 `reportReady()` 請網頁補送 `ready`；iOS 的字級只在載入完成後注入到已換上的那一頁。另一個選項是先查外掛有沒有開放 WebKit 訊息的來源 frame。設計文件 §6.1、§6.2、§6.3 與計畫 Task 5 照此修改（`de0e874`）。

實作代理動手前先在兩個模擬器量了各種導覽實際觸發的回呼，兩度停下來回報和規則對不上的時序。協調者依量到的時序在方案 A 的範圍內補了細節，每一條都寫進設計文件與計畫：

| 量到的時序 | 協調者的裁定 |
|---|---|
| iOS：外部頁換上後自己呼叫 `window.stop()`，只有錯誤回呼、網址不變回去；204、取消、`tel:` 則是先把網址變回原本的、再回報錯誤 | 主框架錯誤結束載入中時，以 WebView 最後回報的網址作為已換上的網址（`973c3c0`） |
| iOS：App 第一次載入時，網址變化比「開始載入」早約 5 秒 | App 自己發起的載入在呼叫時就記為載入中；沒有載入中時、scheme／host／埠改變的網址變化視為開始載入（寧可多擋）（`973c3c0`） |
| Android：導向 204 或取消導覽時只送一次「載入完成」，帶的是 204 的網址，畫面不變 | 這次載入沒有「開始載入」時，「載入完成」不算換上（`afd88e1`）；這次載入中收到過網址變化時，以最後回報的網址為準，不採用「載入完成」帶的網址（`7173c1c`） |

協調者寫給實作代理的測試清單裡有一條（「自家頁導向外部頁的載入中，仍接受自家頁的訊息」）和設計文件衝突，是協調者寫錯，照設計文件改正。

### 複查

**第一輪複查（程式 `b600265..6e65e2e`，文件 `b600265..7173c1c`）：不通過。** 上次的必修第 2 項、應修第 3 項、可之後再做第 5 項已解決；必修第 1 項在原本的情境已解決（外部頁的假 `ready` 40 則全部被擋、載入完成後補送成功；204、`window.stop()`、bfcache 返回都正確），但審查者在 iOS 找到一條新的繞過路徑：

| # | 等級 | 發現 | 協調者的查證 | 處理 |
|---|---|---|---|---|
| 6 | 必修 | iOS 上外部頁換上後仍有資源沒載完（例如很慢的圖片），App 一直把它當成「載入中」；這時它導向自家網址，新的「開始載入」把載入中的外部網址蓋掉，判斷變成「自家＋自家」而放行。實測 28 則假 `ready` 被接受、AppBar 標題被改掉。Android 不會發生 | 讀程式屬實：新的載入直接覆寫載入中的網址 | 協調者裁定：載入中又開始新的載入時，先前的載入中網址也列入判斷，直到這一串載入結束；結束時怎麼決定已換上的網址不變（`470ad23`）。實作 `b5b27a6` |
| 7 | 可之後再做 | 測試沒有涵蓋「錯誤回呼先到、網址變回後到」 | 判斷（實測三輪都是網址先變回） | 寫進設計文件 §6.3 的殘留風險，並加一條釘住目前行為的測試 |

**第二輪複查（`470ad23..b5b27a6`）：通過。** 慢圖片情境在兩個平台都是 0 則被接受，其他情境回歸正常。審查者另外試了三條可能的繞過路徑都沒有被放行。剩下的風險只有設計文件 §6.3 已寫明的兩條：跨網域 iframe，以及「錯誤回呼先到、網址變回後到」。後者在這套「只看網址的回呼」的判斷方式裡無法根治，因為 bfcache 成功返回和真正被取消都是以同一個錯誤碼結束；WebKit 的訊息本身帶有來源 frame，但 `webview_flutter` 沒有開放。實作者把載入中的網址變化也算進這一串，使 iOS 的 204 情境要到錯誤回呼才恢復接受自家頁的訊息（晚約 1 毫秒），審查者認為合理而且必要。

### 協調者自己做的查證

- 讀過 `demo_webview.dart`、`platform_webview.dart`、`demo_page.dart` 全文、C01 的目錄宣告、`pubspec.yaml` 與 `docs/ENVIRONMENT.md` 的 diff。
- 修正後讀過 `demo_webview_logic.dart` 的狀態轉換；每次修正後重跑 `flutter analyze`（零問題）、`flutter test`（205、211 個全過）、`node web/test/run.mjs`（`ALL PASS (68)`）、兩個平台的建置（都成功），並裝進兩個模擬器啟動。
- 重跑 `flutter analyze`（零問題）、`flutter test`（146 個全過）、`node web/test/run.mjs`（`ALL PASS (68)`）、兩個平台的建置（都成功）；裝進兩個模擬器後啟動成功，Android 的 logcat 沒有 `FATAL EXCEPTION` 或 Flutter 錯誤。
- 讀過審查者留下的 iOS 與 Android 紀錄，第 1、2 項的關鍵行和它的報告一致。

### 審查者確認符合的部分

計畫指定的 `snapshot_test` 斷言逐字都在；介面名稱與簽章和計畫一致；上表「派工時補的決定」都做到。模擬器實測（Android 字級 1.5、iOS 最大字級 1.35）：三個變體的表現符合 §7 C01；Android 修正版沒有被放大兩次；Android 導到外部網域時改用 App 負責、返回後改回網頁負責。`pubspec.yaml` 多了兩個測試用的 dev_dependencies（原本就是間接相依），審查者認為可以接受。

### 驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | 設定快照、字級策略對應表、切換變體時換新的控制器、AppBar 標題的來源、選項預設值；已換上／載入中的判斷在 Android 與 iOS 兩種時序下的信任判斷、`reportReady` 補送、設定重送、字級套用到哪一頁 |
| 在模擬器上看過 | 兩個平台：內建網頁載入（iOS 沒有被 ATS 擋）、Bridge 通了（AppBar 標題換成網頁回報的標題）、三個變體切換、大字級下三個變體的表現；iOS 的 In-app browser 開得了內建網頁。實作代理與審查代理用一個「其他網域」的測試伺服器，在兩個平台重現並確認：外部頁的假訊息被擋、204、取消、`window.stop()`、bfcache 返回、慢資源的外部頁導向自家網頁 |
| 沒確認到 | Android 的 In-app browser（模擬器的 Chrome 停在首次啟動畫面，要同意 Chrome 的服務條款，沒有代為同意） |
| 未驗證 | 所有報讀器行為；實機上的一切；iPad 上 `-webkit-text-size-adjust` 是否有效 |
