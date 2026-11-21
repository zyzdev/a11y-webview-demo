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
