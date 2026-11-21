# Flutter WebView 無障礙範例 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task (the user chose subagent-driven execution; see 執行方式 and 執行流程 below). Steps use checkbox (`- [ ]`) syntax for tracking.

> **執行方式：**
> - **使用者已決定：每個任務都要派代理審查**（流程見下方「逐任務審查」），並且**以正確度為優先**，不以省額度或省時間為考量。
> - **使用者選定選項 C：每個任務派一個子代理實作，再派一個代理審查。** 具體訂為：
>   - 地點：開新 session，從這份計畫和設計文件接手。這個主 session 是協調者，不自己寫實作。
>   - 協調者：Fable 5.2、xhigh、fast mode 關。負責派工、查證回報、判斷審查意見、整合。
>   - 每個任務的實作：全新的子代理，Fable 5.2、xhigh。每個任務的 context 都是乾淨的。
>   - 每個任務的審查：Opus 5.5、high 的獨立代理。刻意用和實作不同的模型，盲點才不會重疊（這份計畫的審查就是這樣抓到 5 個必修問題）。
>   - 整體審查：全部完成後另派一個 Opus 5.5、high 代理審查整個專案，重點放在跨任務的一致性。
> - **Task 5 審查通過後停下來，等使用者在實機確認**（見 Task 5 的檢查點），通過後才做其餘頁面。
> - 額度不夠時就暫停等重置。不得為了趕進度而降低模型或強度、跳過審查、或把必修項目留到後面。
> - 成本：依使用者 2026-10-16 的實驗，子代理逐任務實作加審查大約是主 session 自己做的兩倍額度和時間；用 Fable xhigh 會再更多。

**Goal:** 做出一個 Flutter 範例 App 和配合的網頁專案，共 23 個示範頁，讓使用者在實機上用報讀器體驗 WebView 無障礙的配合問題與修正。

**Architecture:** `web/` 是沒有框架的靜態網頁，`shared/a11y-app.js` 實作 App 與網頁的約定。`flutter_app/` 內建一個 `127.0.0.1` 的 HTTP 伺服器提供這些網頁（也可改連外部網址）。共用的 `DemoWebView` 預設把所有修正打開；每個示範頁用一筆 `DemoSpec` 宣告，問題版只關掉該頁自己的那一項修正。

**Tech Stack:** Flutter ≥ 3.41（stable）、`webview_flutter` 4.14.x、`webview_flutter_android` 4.14.x、`webview_flutter_wkwebview` 3.27.x、`url_launcher` 6.3.x、`shared_preferences` 2.5.x、`flutter_localizations`；網頁端純 HTML/CSS/JS。

**Spec:** `docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md`。執行前先讀完，尤其 §5.2 基準原則、§6 約定、§7 各頁設計。

## Global Constraints

- 專案根目錄是 `a11y-webview-demo/`；下面所有路徑都相對於它。
- Flutter stable ≥ 3.41.0。只建 `android` 和 `ios` 兩個平台。Android `minSdk` ≥ 24，iOS ≥ 13.0。
- 套件用 `flutter pub add` 取當下版本，下限：`webview_flutter` 4.14.1、`webview_flutter_android` 4.14.1、`webview_flutter_wkwebview` 3.27.2、`url_launcher` 6.3.3、`shared_preferences` 2.5.6。
- 不使用已棄用的 API：用 `SemanticsService.sendAnnouncement`（不是 `announce`）、`PopScope.onPopInvokedWithResult`（不是 `onPopInvoked`）、`TextScaler`（不是 `textScaleFactor`）。SDK 缺少計畫指定的 API 時停下來回報，不自行替換。
- 不使用 `MediaQuery.reduceMotionOf`（要 3.50 才有）。iOS 的減少動態從 `View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion` 讀。
- 約定的名稱一字不改：JS 頻道 `A11yBridge`、JS 物件 `window.a11yApp`、URL 參數 `mode`、`off`、`embedded`、`lang`、`theme`、`textScale`、`bold`、`contrast`、`reduceMotion`（順序固定如此）。
- 內建伺服器綁 `127.0.0.1`，網址也用 `127.0.0.1`，不用 `localhost`。
- 基準原則（設計文件 §5.2）：同一頁的各變體之間，只有該頁要示範的修正不同；基準的修正不得改變其他頁問題版的樣子。
- 朗讀原則（設計文件 §6.4）：一件事只用一種方式告知。基準不主動朗讀頁面標題。
- 網頁不用框架、不需建置、不載入任何外部資源（要能離線）。每頁 `<head>` 有 `<meta name="color-scheme" content="light dark">`。
- 介面文字一律繁體中文（台灣用語）。程式識別字用英文；解釋無障礙理由的註解用繁體中文。
- 誠實標示：每頁的可信度、平台、依據照設計文件 §4 填。不得在程式、頁面或 README 宣稱報讀器行為已驗證。
- 明文 HTTP 相關設定都加註解「僅供示範，正式專案不可照抄」。
- 每個任務結束時：`flutter analyze` 零問題、`flutter test` 全過、App 可建置，然後 commit，接著依「逐任務審查」送審。必修項目修完才開始下一個任務。

## 執行流程

使用 superpowers:subagent-driven-development。下面是在那個流程之上的額外規定；兩者不一致時以這裡為準。

開新 session 的主 session 是**協調者**：不自己寫實作，負責派工、查證、判斷審查意見、整合，以及和使用者溝通。Task 0（環境檢查）由協調者自己做。

**額度：** 每個任務開始前查一次方案用量。每週的 Fable 或全模型額度剩不到 10% 時不開始新任務，停下來回報，等重置後再繼續。

### 實作代理

Task 1 到 Task 12 每個任務派一個全新的代理實作，每次都明確指定模型與強度：general-purpose、Fable 5.2、xhigh。

- **交給它的內容：** 該任務的完整文字、Global Constraints、每一頁的完成定義、設計文件與本計畫的路徑、目前的 commit。
- **要求它：** 動手前先讀這個任務 Consumes 的既有程式碼，以程式碼為準，不憑計畫想像；照步驟先寫測試、確認失敗、再實作；跑完該任務列出的所有驗證；commit；回報做了什麼、測試的實際輸出、和計畫不一致的地方、自己不確定的地方。
- **對不上時：** 計畫和現有程式碼不一致，或計畫指定的 API 不存在時，它要停下來回報，不自行改介面或換成別的 API。
- **協調者查證：** 收到回報後，協調者自己看 diff，並重跑 `flutter analyze`、`flutter test`、`node web/test/run.mjs`。代理的回報只是說法，不是證據。

### 逐任務審查

Task 1 到 Task 12 每個任務都要做。Task 0 沒有可審查的產出，不送審。

實作代理 commit、協調者確認測試通過之後，開始下一個任務之前：

1. **記下範圍。** 這個任務的 commit 範圍（上一個任務結尾的 commit 到 `HEAD`）。
2. **派審查代理。** 一個全新的 general-purpose 代理，每次都明確指定模型與強度：Opus 5.5、high。只給它三樣東西：設計文件的路徑、本計畫的路徑與任務編號、commit 範圍。不給實作者自己的結論或自評。要求它不修改任何檔案。
3. **審查代理要檢查：**
   - 這個任務的 Files、Interfaces、每個步驟是否都做到；名稱、簽章、型別是否和計畫一致。
   - 測試是否真的在驗證行為：沒有空測試、沒有把計畫裡的斷言改弱或刪掉。自己重跑 `flutter analyze`、`flutter test`、`node web/test/run.mjs`。
   - Global Constraints 每一條，尤其基準原則、朗讀原則、不用已棄用的 API、約定名稱、誠實標示。
   - 這個任務的示範頁：各變體之間的差異是否只有該頁要示範的修正；「怎麼測」的內容是否符合設計文件 §7；可信度和依據是否照 §4。
   - 有沒有超出這個任務範圍的改動。
   - 輸出：每項發現標「必修／應修／可之後再做」，附檔案和行號，並說明是實際查證過還是判斷。
4. **協調者逐項判斷。** 先查證再決定，不照單全收。不採納的項目要寫下技術理由。
5. **修正與複查。** 必修項目交回同一個實作代理修正（接續原本的代理，讓它保有脈絡），另外 commit。協調者重跑全部測試後，請同一個審查代理複查這次修正。必修項目全部通過，這個任務才算完成。
6. **留紀錄。** 在 `docs/REVIEW_LOG.md` 追加一段：任務編號、審查代理的模型與強度、各等級的發現數、每項怎麼處理。

Task 5 的實機檢查點排在這個任務的審查通過之後。

**每一頁的完成定義（任務 5–11 的每個示範頁都適用）**

1. `web/pages/<檔名>` 存在，`<body data-page="<id>" data-fixes="<本頁修正>">` 正確；單獨在瀏覽器開，`?mode=problem` 和 `?mode=fixed` 的行為符合設計文件 §7。
2. `demo_catalog.dart` 有對應的 `DemoSpec`：變體、修正方、可信度、平台照設計文件 §4；`HowToTest` 的前置、步驟、問題版預期、修正版預期、依據、程式位置齊全，內容依設計文件 §7 撰寫。
3. 已執行 `tool/sync_web.sh`。
4. 在模擬器開啟該頁，每個變體都能載入網頁。

## Review Focus

1. **外部網址輸入不合法**（空字串、沒有 scheme、`localhost:8000`、`ftp://`）：設定頁應拒絕或自動補 `http://`，不能讓 WebView 載入壞網址後一片空白。→ Task 4 `parseExternalBase` 測試。
2. **App 從背景回來後內建伺服器已失效**（iOS 暫停 App 時回收 socket）：回到前景應自動在原埠恢復，頁面不用重開。→ Task 3 `ensureRunning` 測試。
3. **網頁送來壞掉、不認得或來路不明的 Bridge 訊息**（非 JSON、缺欄位、未知 `type`、超長字串、來自非自家網域的頁面）：App 忽略，不當掉。→ Task 2 `BridgeMessage.parse` 與 `isTrustedPage` 測試。
4. **極端字級與缺參數**（系統字級 3 倍以上、網頁被不帶參數直接開啟、參數被亂填）：限制在 0.8–3.0，其餘回到預設。→ Task 1 網頁自我測試、Task 2 `normalizeTextScale` 測試。
5. **載入被取消或外部程式開不了**（慢速載入中再點連結、模擬器沒有電話和郵件、In-app browser 連不到內建網頁）：不能誤顯示錯誤畫面，也不能沒反應。→ Task 8 `shouldShowErrorView` 與 `launchFailureMessage` 測試、Task 5 的 SnackBar。

---

## File Structure

```
web/
  index.html                     目錄頁
  shared/a11y-app.js             A11yCore（純函式）＋ window.a11yApp（執行期）
  shared/base.css                配色變數、rem 排版、header、狀態類別
  pages/c01-text-scale.html … c11-safe-area.html
  pages/a01-loading-error.html, a02-js-dialogs.html, a03-links.html
  pages/b-content.html           A04、A05、B01–B05、T02 共用
  pages/t01-diagnostics.html
  test/tests.js, test/index.html, test/run.mjs   同一份測試，瀏覽器和 Node 都能跑
flutter_app/
  tool/sync_web.sh               rsync ../web/ → assets/web/
  assets/web/**                  複本（納入版控）
  lib/main.dart                  載入設定、啟動伺服器、runApp
  lib/app.dart                   MaterialApp、AppScope、生命週期監聽
  lib/contract/web_contract.dart     URL 與 JS 字串組合、自家網域判斷
  lib/contract/bridge_message.dart   網頁→App 訊息解析
  lib/contract/back_decision.dart    返回決策
  lib/contract/navigation_policy.dart 連結分類、失敗訊息、是否顯示錯誤畫面（Task 8）
  lib/server/local_web_server.dart
  lib/settings/app_settings.dart, settings_page.dart
  lib/catalog/demo_spec.dart, demo_catalog.dart
  lib/webview/demo_webview_config.dart, demo_web_controller.dart, demo_webview.dart, platform_webview.dart
  lib/widgets/demo_scaffold.dart, how_to_test_panel.dart, demo_page.dart, web_error_view.dart
  lib/pages/home_page.dart
  lib/demos/layouts.dart         需要特殊版面的 bodyBuilder
  test/**                        與 lib 對應
README.md, docs/CONTRACT.md, docs/ENVIRONMENT.md, docs/REVIEW_LOG.md
```

---

### Task 0: 環境確認與版控初始化

**Files:**
- Create: `.gitignore`、`docs/ENVIRONMENT.md`

- [ ] **Step 1: 檢查 Flutter**

Run: `flutter --version`
Expected: 版本 ≥ 3.41.0，channel stable。指令不存在或版本不足 → **停下來回報使用者**，不要自行安裝或升級。

- [ ] **Step 2: 檢查平台工具鏈與輔助工具**

Run: `flutter doctor -v`、`python3 --version`、`node --version`、`xcrun simctl list devices available | grep -i iphone | head -3`、`flutter emulators`
Expected: Android toolchain 和 Xcode 至少一個可用。兩個都不可用 → 停下來回報。只有一個可用 → 繼續，並在 `ENVIRONMENT.md` 記下另一個平台未驗證。`node` 不存在不算失敗（網頁測試改用瀏覽器跑）。

- [ ] **Step 3: 寫 `docs/ENVIRONMENT.md`**

記錄：Flutter 與 Dart 版本、可用平台、可用的模擬器名稱、有沒有 `node`、未驗證的項目。

- [ ] **Step 4: 版控**

目錄還不是 git repo 時執行 `git init`。`.gitignore` 排除 `.DS_Store`。

```bash
git add .gitignore docs && git commit -m "docs: add design, plan and environment notes"
```

---

### Task 1: 網頁核心

**Files:**
- Create: `web/shared/a11y-app.js`、`web/shared/base.css`、`web/index.html`、`web/pages/b-content.html`、`web/test/tests.js`、`web/test/index.html`、`web/test/run.mjs`

**Interfaces:**
- Produces（`a11y-app.js`；`A11yCore` 不碰 DOM，執行期部分只在 `typeof document !== 'undefined'` 時執行；檔尾 `if (typeof module !== 'undefined') module.exports = { A11yCore }`）：

```js
A11yCore.CONTRACT_VERSION            // 1
A11yCore.parseParams(search)         // → {mode, off, embedded, lang, theme, textScale, bold, contrast, reduceMotion}
A11yCore.fixEnabled(name, pageFixes, mode, off)   // → boolean
A11yCore.effectiveTheme({param, systemDark, honorParam})  // → 'light' | 'dark'
A11yCore.rootFontPercent(textScale, honor)   // → number
A11yCore.resolvePref({media, param, honorParam})  // → boolean

window.a11yApp = {
  params,                         // parseParams(location.search) 的結果
  fixEnabled(name),               // 用 <body data-fixes>、params.mode、params.off
  postToApp(obj),                 // 有 window.A11yBridge 才送 JSON，否則不做事
  reportReady(), reportRoute(title, path), setBackState(canHandleBack), requestClose(),
  updateSettings(obj),            // App 呼叫；套用後觸發 onSettingsChanged 的回呼
  onSettingsChanged(cb),
  setBackHandler(fn), handleBack(),                 // App 呼叫 handleBack → 執行 fn
  setDialogHandler(fn), onNativeDialogClosed(requestId, action),
  setSubmitHandler(fn), submitForm(),
}
```

- 修正名稱（`data-fixes` 的詞彙）：`textScale`、`theme`、`a11yPrefs`、`lang`、`embeddedChrome`、`embeddedTitle`、`arrival`、`routeFocus`、`back`、`zoom`、`dialogReturn`、`formErrors`、`formFeedback`、`safeArea`。
- `fixEnabled` 的規則：只有本頁 `data-fixes` 列出的修正可以被關掉；`mode=problem` 關掉全部列出的，`off` 關掉其中指定的。沒列在本頁的修正永遠啟用。
- DOM 約定：載入時在 `<html>` 設 `data-mode`、`data-theme`、`data-embedded`；每個被關掉的修正加 class `nofix-<name>`；偏好加 class `pref-bold`、`pref-contrast`、`pref-reduce-motion`；根字級用 `style.fontSize = <percent>%`。
- 每頁的 header：`<header class="site-header">`，內含網站名稱、`<h1>`、回上一頁連結。在 App 內（`embedded`）時，`embeddedChrome` 啟用就隱藏網站名稱和返回連結，`embeddedTitle` 啟用就隱藏 `<h1>`。不在 App 內時，header 另外顯示「問題版／修正版」切換連結。
- `arrival` 啟用時：`DOMContentLoaded` 後自動 `reportReady()`，送 `{type:'ready', title: document.title, lang: <html lang>, contract: 1, caps: [目前啟用的修正名稱]}`；`pageshow` 事件的 `persisted` 為 true 時再送一次。
- 朗讀的分工（設計文件 §6.4）：`reportRoute` 在 App 內只送訊息給 App；不在 App 內時改把標題寫進頁面上一個 `aria-live="polite"` 的隱藏區域。`routeFocus` 啟用時，頁面換畫面後把焦點移到新畫面的標題。

- [ ] **Step 1: 寫失敗的測試 `web/test/tests.js`**（只用全域的 `A11yCore` 和 `eq`，不依賴執行環境）

```js
eq(A11yCore.parseParams(''), {mode:'fixed', off:[], embedded:false, lang:null, theme:null, textScale:null, bold:null, contrast:null, reduceMotion:null});
eq(A11yCore.parseParams('?mode=problem&off=routeFocus%2CformFeedback&embedded=1&lang=zh-TW&theme=dark&textScale=1.30&bold=1&contrast=0&reduceMotion=1'),
   {mode:'problem', off:['routeFocus','formFeedback'], embedded:true, lang:'zh-TW', theme:'dark', textScale:1.3, bold:true, contrast:false, reduceMotion:true});
var bad = A11yCore.parseParams('?mode=evil&off=a%3Cb,ok&theme=pink&textScale=abc&lang=%3Cscript%3E');
eq(bad.mode, 'fixed');
eq(bad.off, ['ok']);
eq(bad.theme, null);
eq(bad.textScale, null);
eq(bad.lang, null);
eq(A11yCore.parseParams('?textScale=9').textScale, 3);
eq(A11yCore.parseParams('?textScale=0.1').textScale, 0.8);
eq(A11yCore.fixEnabled('textScale', ['textScale'], 'problem', []), false);
eq(A11yCore.fixEnabled('theme', ['textScale'], 'problem', []), true);
eq(A11yCore.fixEnabled('textScale', ['textScale'], 'fixed', []), true);
eq(A11yCore.fixEnabled('routeFocus', ['arrival','routeFocus'], 'fixed', ['routeFocus']), false);
eq(A11yCore.fixEnabled('arrival', ['arrival','routeFocus'], 'fixed', ['routeFocus']), true);
eq(A11yCore.fixEnabled('theme', ['textScale'], 'fixed', ['theme']), true);   // off 只對本頁宣告的修正有效
eq(A11yCore.effectiveTheme({param:'dark', systemDark:false, honorParam:true}), 'dark');
eq(A11yCore.effectiveTheme({param:'dark', systemDark:false, honorParam:false}), 'light');
eq(A11yCore.effectiveTheme({param:null, systemDark:true, honorParam:true}), 'dark');
eq(A11yCore.rootFontPercent(1.3, true), 130);
eq(A11yCore.rootFontPercent(1.3, false), 100);
eq(A11yCore.rootFontPercent(null, true), 100);
eq(A11yCore.resolvePref({media:false, param:true, honorParam:true}), true);
eq(A11yCore.resolvePref({media:false, param:true, honorParam:false}), false);
eq(A11yCore.resolvePref({media:true, param:null, honorParam:false}), true);
```

合法格式：`lang` 是 `/^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$/`；`off` 的每個名稱是 `/^[A-Za-z]+$/`。

兩個執行器都定義 `eq`（深層比較、計數）後載入 `tests.js`：
- `test/index.html`：在 `<pre id="result">` 顯示 `ALL PASS (N)` 或逐條 `FAIL: …`，並把 `document.title` 設為 `PASS` 或 `FAIL`。
- `test/run.mjs`：用 `createRequire` 載入 `../shared/a11y-app.js` 取得 `A11yCore` 掛到 `globalThis`，用 `vm.runInThisContext` 執行 `tests.js`，印出同樣的結果；有失敗時 exit code 為 1。

- [ ] **Step 2: 確認測試失敗**

Run: `node web/test/run.mjs`
Expected: 失敗（`A11yCore` 未定義或檔案不存在）。
沒有 `node` 時：`cd web && python3 -m http.server 8765`（背景執行），用 Browser pane 開 `http://127.0.0.1:8765/test/` 並讀 `document.title`，預期是 `FAIL`。後面各任務的網頁測試都用同樣的替代方式。

- [ ] **Step 3: 實作 `a11y-app.js`、`base.css`**

`base.css`：淺色與深色兩組 CSS 變數（由 `html[data-theme]` 切換，對比至少 4.5:1）；全部用 `rem`；`.pref-reduce-motion` 下關閉動畫與轉場；`.pref-contrast` 下提高對比；`.pref-bold` 下內文加粗；`.visually-hidden` 工具類別。

- [ ] **Step 4: 確認測試通過**

Run: `node web/test/run.mjs`　Expected: `ALL PASS (24)`。

- [ ] **Step 5: 寫 `b-content.html` 和 `index.html`**

`b-content.html`（`data-page="b-content" data-fixes=""`）：標題階層、三個連結、兩個按鈕、三段以上長文（要能捲動）、一個含單行輸入框與多行輸入框的表單、一個 `<p id="live-status" aria-live="polite">`。`index.html`：列出所有頁面的連結清單（之後每個任務補上新頁）。

- [ ] **Step 6: 瀏覽器檢查**

用 Browser pane 開 `http://127.0.0.1:8765/pages/b-content.html?theme=dark&textScale=1.5`，讀 `document.documentElement.dataset.theme`（預期 `dark`）和 `document.documentElement.style.fontSize`（預期 `150%`）。加上 `&embedded=1` 後，header 裡的 `<h1>` 的 `offsetParent` 為 `null`（已隱藏）。

- [ ] **Step 7: Commit**

```bash
git add web && git commit -m "feat(web): contract core, base styles and self-tests"
```

---

### Task 2: Flutter 專案與純 Dart 約定層

**Files:**
- Create: `flutter_app/`（`flutter create`）、`lib/contract/web_contract.dart`、`lib/contract/bridge_message.dart`、`lib/contract/back_decision.dart`
- Test: `test/contract/web_contract_test.dart`、`bridge_message_test.dart`、`back_decision_test.dart`

**Interfaces:**
- Produces:

```dart
// web_contract.dart
class WebSettingsSnapshot {            // 值相等（== 與 hashCode）
  const WebSettingsSnapshot({this.lang, this.theme, this.textScale, this.bold, this.contrast, this.reduceMotion});
  final String? lang; final String? theme; final double? textScale;
  final bool? bold; final bool? contrast; final bool? reduceMotion;
}
double normalizeTextScale(double raw);                 // 限制 0.8–3.0，四捨五入到兩位
Uri buildDemoUri({required Uri base, required String webPath, required String webMode, List<String> webOff = const [],
    required bool embedded, WebSettingsSnapshot settings = const WebSettingsSnapshot(),
    Map<String, String> extraQuery = const {}});
String jsCall(String method, [List<Object?> args = const []]);
String updateSettingsScript(WebSettingsSnapshot s);    // = jsCall('updateSettings', [非 null 欄位的 Map])
bool isTrustedPage(Uri? current, Uri webBase);         // scheme、host、port 相同，且路徑在 webBase 的路徑之下

// bridge_message.dart
sealed class BridgeMessage { static BridgeMessage? parse(String raw); }
final class ReadyMessage extends BridgeMessage { final String title; final String? lang; final int contract; final List<String> caps; }
final class RouteChangedMessage extends BridgeMessage { final String title; final String path; }
final class BackStateMessage extends BridgeMessage { final bool canHandleBack; }
final class OpenNativeDialogMessage extends BridgeMessage { final String requestId, title, message; final List<String> actions; }
final class FormResultMessage extends BridgeMessage { final bool ok; final int errorCount; final String firstError; }
final class CloseMessage extends BridgeMessage {}

// back_decision.dart
enum BackAction { askWeb, webHistoryBack, popRoute }
BackAction decideBack({required bool webWantsBack, required bool webCanGoBack});
bool routeCanPop({required bool webWantsBack, required bool webCanGoBack});
```

六個訊息類別都有 `const` 建構子，欄位是具名參數。可省略的：`ReadyMessage.lang`（預設 null）、`contract`（預設 0）、`caps`（預設空清單）、`FormResultMessage.firstError`（預設空字串）；其餘必填。後續任務的測試會直接建構它們。

- [ ] **Step 1: 建立專案與套件**

```bash
flutter create --org com.example.a11ydemo --project-name a11y_webview_demo --platforms=android,ios flutter_app
cd flutter_app && flutter pub add webview_flutter webview_flutter_android webview_flutter_wkwebview url_launcher shared_preferences
flutter pub add flutter_localizations --sdk=flutter
```

確認解析出的版本不低於 Global Constraints 的下限，並把版本補進 `docs/ENVIRONMENT.md`。刪掉範本的計數器程式和 `test/widget_test.dart`。

- [ ] **Step 2: 寫失敗的測試**

```dart
// web_contract_test.dart
test('all settings', () {
  final uri = buildDemoUri(base: Uri.parse('http://127.0.0.1:8123/'), webPath: 'pages/c06-arrival.html',
      webMode: 'fixed', webOff: const ['routeFocus'], embedded: true,
      settings: const WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3, bold: true, contrast: false, reduceMotion: true));
  expect(uri.toString(), 'http://127.0.0.1:8123/pages/c06-arrival.html?mode=fixed&off=routeFocus&embedded=1&lang=zh-TW&theme=dark&textScale=1.30&bold=1&contrast=0&reduceMotion=1');
});
test('omits nulls, keeps base path', () {
  final uri = buildDemoUri(base: Uri.parse('http://10.0.2.2:8000/web/'), webPath: 'pages/b-content.html', webMode: 'problem', embedded: false);
  expect(uri.toString(), 'http://10.0.2.2:8000/web/pages/b-content.html?mode=problem');
});
test('multiple off values and extra query', () {
  final uri = buildDemoUri(base: Uri.parse('http://127.0.0.1:8123/'), webPath: 'pages/a.html', webMode: 'fixed',
      webOff: const ['arrival', 'routeFocus'], embedded: false, extraQuery: const {'__delay': '3000'});
  expect(uri.toString(), 'http://127.0.0.1:8123/pages/a.html?mode=fixed&off=arrival%2CrouteFocus&__delay=3000');
});
test('normalizeTextScale', () {
  expect(normalizeTextScale(0.5), 0.8); expect(normalizeTextScale(3.12), 3.0); expect(normalizeTextScale(1.2999), 1.3);
});
test('jsCall', () {
  expect(jsCall('handleBack'), 'window.a11yApp&&window.a11yApp.handleBack();');
  expect(jsCall('onNativeDialogClosed', ['r1', '刪除']), 'window.a11yApp&&window.a11yApp.onNativeDialogClosed("r1","刪除");');
});
test('updateSettingsScript', () {
  expect(updateSettingsScript(const WebSettingsSnapshot(theme: 'dark', textScale: 1.3)),
      'window.a11yApp&&window.a11yApp.updateSettings({"theme":"dark","textScale":1.3});');
});
test('isTrustedPage', () {
  final base = Uri.parse('http://127.0.0.1:8123/');
  expect(isTrustedPage(Uri.parse('http://127.0.0.1:8123/pages/a.html?x=1'), base), true);
  expect(isTrustedPage(Uri.parse('http://127.0.0.1:9999/'), base), false);
  expect(isTrustedPage(Uri.parse('https://example.com/'), base), false);
  expect(isTrustedPage(null, base), false);
  final sub = Uri.parse('http://10.0.2.2:8000/web/');
  expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/web/pages/a.html'), sub), true);
  expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/other/a.html'), sub), false);
});

// bridge_message_test.dart
final ready = BridgeMessage.parse('{"type":"ready","title":"字體大小","lang":"zh-TW","contract":1,"caps":["textScale","theme"]}') as ReadyMessage;
expect(ready.title, '字體大小'); expect(ready.contract, 1); expect(ready.caps, ['textScale', 'theme']);
final bare = BridgeMessage.parse('{"type":"ready","title":"x"}') as ReadyMessage;
expect(bare.contract, 0); expect(bare.caps, isEmpty); expect(bare.lang, isNull);
expect(BridgeMessage.parse('{"type":"routeChanged","title":"詳情","path":"/detail"}'), isA<RouteChangedMessage>());
expect(BridgeMessage.parse('{"type":"backState","canHandleBack":true}'), isA<BackStateMessage>().having((m) => m.canHandleBack, 'v', true));
expect(BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"刪除","message":"確定？","actions":["取消","刪除"]}'),
    isA<OpenNativeDialogMessage>().having((m) => m.actions, 'actions', ['取消', '刪除']));
expect(BridgeMessage.parse('{"type":"formResult","ok":false,"errorCount":2,"firstError":"請輸入姓名"}'), isA<FormResultMessage>());
expect((BridgeMessage.parse('{"type":"formResult","ok":true,"errorCount":0}') as FormResultMessage).firstError, '');
expect(BridgeMessage.parse('{"type":"close"}'), isA<CloseMessage>());
expect(BridgeMessage.parse('not json'), isNull);
expect(BridgeMessage.parse('[]'), isNull);
expect(BridgeMessage.parse('{"type":"unknown"}'), isNull);
expect(BridgeMessage.parse('{"type":"ready"}'), isNull);                            // 缺必要欄位
expect(BridgeMessage.parse('{"type":"backState","canHandleBack":"yes"}'), isNull);  // 型別不對
final long = BridgeMessage.parse('{"type":"ready","title":"${'字' * 500}"}') as ReadyMessage;
expect(long.title.length, 200);                                                      // 字串欄位截到 200 字

// back_decision_test.dart
expect(decideBack(webWantsBack: true, webCanGoBack: true), BackAction.askWeb);
expect(decideBack(webWantsBack: false, webCanGoBack: true), BackAction.webHistoryBack);
expect(decideBack(webWantsBack: false, webCanGoBack: false), BackAction.popRoute);
expect(routeCanPop(webWantsBack: false, webCanGoBack: false), true);
expect(routeCanPop(webWantsBack: true, webCanGoBack: false), false);
```

- [ ] **Step 3: 確認失敗**

Run: `flutter test test/contract`　Expected: 編譯失敗（符號未定義）。

- [ ] **Step 4: 實作三個檔案**

`buildDemoUri` 自己組查詢字串（不用 `queryParameters` 的 Map，順序才固定）：順序為 `mode, off, embedded, lang, theme, textScale, bold, contrast, reduceMotion`，最後接 `extraQuery`；每個值經過 `Uri.encodeQueryComponent`；`off` 是用逗號接起來的一個值，清單為空時不輸出；`embedded` 為 false 時不輸出；`textScale` 用 `toStringAsFixed(2)`；布林輸出 `1`／`0`。`jsCall` 的引數用 `jsonEncode`，以逗號相接、不加空白。

- [ ] **Step 5: 確認通過並 commit**

Run: `flutter test test/contract && flutter analyze`　Expected: 全過、零問題。

```bash
git add flutter_app && git commit -m "feat(app): scaffold project and contract layer"
```

---

### Task 3: 內建伺服器、assets 同步、平台設定

**Files:**
- Create: `lib/server/local_web_server.dart`、`tool/sync_web.sh`、`android/app/src/main/res/xml/network_security_config.xml`、`assets/web/**`
- Modify: `pubspec.yaml`（assets）、`android/app/src/main/AndroidManifest.xml`、`ios/Runner/Info.plist`
- Test: `test/server/local_web_server_test.dart`、`test/assets_sync_test.dart`

**Interfaces:**
- Produces:

```dart
typedef AssetLoader = Future<List<int>?> Function(String relativePath);   // 找不到回傳 null
class LocalWebServer {
  LocalWebServer({required AssetLoader loader});
  Uri? get baseUri;                 // 例如 http://127.0.0.1:53124/
  Future<Uri> start();              // 已啟動時回傳現有 baseUri
  Future<void> stop();
  Future<Uri> ensureRunning();      // 自我探測；失效時優先在原埠重啟，原埠被佔才換埠
  @visibleForTesting Future<void> debugCloseSocket();   // 只關底層 HttpServer、不清狀態，模擬 socket 被系統回收
  static String? normalizePath(String rawPath);   // '/' → 'index.html'；含 '..' → null
  static String contentTypeFor(String path);
  static Duration parseDelay(String? raw);         // 查詢參數 __delay（毫秒）；限制 0–10000；不合法 → 0
}
AssetLoader rootBundleLoader({String prefix = 'assets/web/'});
```

- [ ] **Step 1: 寫失敗的測試**（用 `test()`，不要初始化 Flutter binding；用 `dart:io` 的 `HttpClient` 發請求）

```dart
final requested = <String>[];
final files = {'index.html': utf8.encode('<h1>home</h1>'), 'shared/a11y-app.js': utf8.encode('var a=1;')};
final server = LocalWebServer(loader: (p) async { requested.add(p); return files[p]; });
// start：host 為 127.0.0.1、port > 0；再呼叫一次 start 回傳同一個 Uri
// GET /                         → 200，body '<h1>home</h1>'，content-type 'text/html; charset=utf-8'，cache-control 'no-store'
// GET /shared/a11y-app.js?x=1   → 200，content-type 'text/javascript; charset=utf-8'
// GET /pages/missing.html       → 404
// POST /                        → 405
// GET /index.html?__delay=80    → 200，耗時 ≥ 80ms
// 路徑穿越：用原始 Socket 寫入 'GET /../secret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n'
//   → 回應狀態列是 400 或 404；requested 裡沒有任何含 '..' 的路徑
//   （不能用 HttpClient 測，它送出前就把 '..' 正規化掉了）
// stop 之後 start               → 埠號和之前相同
// debugCloseSocket 之後 ensureRunning → 埠號相同，GET / 回 200
expect(LocalWebServer.contentTypeFor('a.css'), 'text/css; charset=utf-8');
expect(LocalWebServer.contentTypeFor('a.svg'), 'image/svg+xml');
expect(LocalWebServer.contentTypeFor('a.png'), 'image/png');
expect(LocalWebServer.contentTypeFor('a.json'), 'application/json; charset=utf-8');
expect(LocalWebServer.contentTypeFor('a.mjs'), 'text/javascript; charset=utf-8');
expect(LocalWebServer.contentTypeFor('a.bin'), 'application/octet-stream');
expect(LocalWebServer.normalizePath('/'), 'index.html');
expect(LocalWebServer.normalizePath('/pages/'), 'pages/index.html');
expect(LocalWebServer.normalizePath('/a/../b'), isNull);
expect(LocalWebServer.parseDelay('80'), const Duration(milliseconds: 80));
expect(LocalWebServer.parseDelay('999999'), const Duration(seconds: 10));
expect(LocalWebServer.parseDelay('-5'), Duration.zero);
expect(LocalWebServer.parseDelay('abc'), Duration.zero);
expect(LocalWebServer.parseDelay(null), Duration.zero);
```

`assets_sync_test.dart`：`../web` 和 `assets/web` 的相對檔案清單相同，且每個檔案內容位元組相同。

- [ ] **Step 2: 確認失敗**　Run: `flutter test test/server test/assets_sync_test.dart`

- [ ] **Step 3: 實作伺服器與同步腳本**

`tool/sync_web.sh`（在 `flutter_app/` 下執行）：`rsync -a --delete ../web/ assets/web/`。`pubspec.yaml` 的 assets 要逐一列出目錄（Flutter 不會遞迴）：`assets/web/`、`assets/web/shared/`、`assets/web/pages/`、`assets/web/test/`。執行一次同步。

- [ ] **Step 4: 平台設定**

Android `AndroidManifest.xml`：`<uses-permission android:name="android.permission.INTERNET"/>`；`<application android:networkSecurityConfig="@xml/network_security_config">`；`<queries>` 加入 `android.support.customtabs.action.CustomTabsService` 的 intent，以及 `tel`、`mailto` 的 `VIEW` intent。`network_security_config.xml` 內容為 `<base-config cleartextTrafficPermitted="true"/>`。確認 `minSdk` ≥ 24，並確認 `res/values-night/styles.xml` 存在（範本預設有；設計文件 §7 C02 需要它）。

iOS `Info.plist`：`NSAppTransportSecurity` 內 `NSAllowsLocalNetworking = true`、`NSAllowsArbitraryLoadsInWebContent = true`；`CFBundleLocalizations` 為 `en`、`zh-Hant`（設計文件 §7 C04 需要）；`NSLocalNetworkUsageDescription`（說明是連到同一個區域網路上的示範網頁伺服器；Apple 的技術文件說 WKWebView 的流量不需要這個權限，加上只是保險）。

- [ ] **Step 5: 確認通過並 commit**

Run: `flutter test && flutter analyze`

```bash
git add -A && git commit -m "feat(app): local web server, asset sync and platform config"
```

---

### Task 4: 設定、目錄模型、首頁與共用頁框

**Files:**
- Create: `lib/settings/app_settings.dart`、`lib/settings/settings_page.dart`、`lib/catalog/demo_spec.dart`、`lib/catalog/demo_catalog.dart`、`lib/webview/demo_webview_config.dart`、`lib/webview/demo_web_controller.dart`、`lib/widgets/demo_scaffold.dart`、`lib/widgets/how_to_test_panel.dart`、`lib/pages/home_page.dart`、`lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/settings/app_settings_test.dart`、`test/webview/demo_webview_config_test.dart`、`test/catalog/demo_catalog_test.dart`、`test/widgets/demo_scaffold_test.dart`、`test/pages/home_page_test.dart`

**Interfaces:**
- Consumes: `LocalWebServer`、`rootBundleLoader`（Task 3）；`BridgeMessage`（Task 2）
- Produces:

```dart
// app_settings.dart
enum WebSource { builtIn, external }
class AppSettings extends ChangeNotifier {
  static Future<AppSettings> load(SharedPreferences prefs);
  WebSource get webSource; String get externalBaseUrl; ThemeMode get themeMode; bool get androidHybridComposition;
  Future<void> setWebSource(WebSource v); Future<void> setExternalBaseUrl(String v);
  Future<void> setThemeMode(ThemeMode v); Future<void> setAndroidHybridComposition(bool v);
  static Uri? parseExternalBase(String input);
}
// SharedPreferences 的 key 就是上面的屬性名稱；預設值：builtIn、''、ThemeMode.system、false

// demo_webview_config.dart
enum TextScaleStrategy { none, webOwned, appOwned }
enum ArrivalAnnounce { none, liveRegionTitle, sendAnnouncement }
class DemoWebViewConfig {
  const DemoWebViewConfig({this.textScale = TextScaleStrategy.webOwned, this.passTheme = true, this.passA11yPrefs = true,
    this.passLang = true, this.langOverride, this.titleFromWeb = true, this.arrival = ArrivalAnnounce.none,
    this.syncBackWithWeb = true, this.accessibleLoadingAndError = true, this.handleJsDialogs = true,
    this.handleExternalNavigation = true, this.enableZoom = true,
    this.androidHybridComposition});            // null = 依 AppSettings
  static const baseline = DemoWebViewConfig();
  DemoWebViewConfig copyWith({...});            // 每個欄位一個具名參數
}
// 設計文件 §6.1：「網頁負責」只套用在自家網域的頁面
TextScaleStrategy effectiveTextScaleStrategy(TextScaleStrategy configured, {required bool trustedPage});

// demo_web_controller.dart（本任務只定義狀態與介面；由 Task 5 的 DemoWebView 驅動）
class DemoWebController extends ChangeNotifier {
  String? webTitle; int webContract = 0; List<String> webCaps = const [];
  bool loading = false; bool mainFrameFailed = false; String? failureDescription;
  bool webWantsBack = false; bool webCanGoBack = false;
  Stream<BridgeMessage> get messages;
  void addMessage(BridgeMessage m);          // DemoWebView 收到 Bridge 訊息時呼叫；測試也用它送假訊息
  void attach(WebViewController c);          // DemoWebView 建立 WebView 後呼叫；未 attach 時下面四個方法不做事
  Future<void> runJavaScript(String js); Future<void> reload(); Future<void> loadUri(Uri uri); Future<void> goBack();
}
// 不是 final class：測試會繼承它並覆寫 runJavaScript 來記錄收到的 JS 字串

// demo_spec.dart
enum DemoCategory { contract, appOnly, boundary, tool }     // 對應代號開頭 c、a、b、t
enum FixSide { app, web, both, either, none }                // 顯示為：App／網頁／兩邊／App 或網頁擇一／（不顯示）
enum Confidence { verified, needsDeviceTest, observation }
enum DemoPlatform { both, android, ios }
class DemoVariant { const DemoVariant(this.id, this.label, {this.webMode = 'fixed', this.webOff = const []});
  final String id, label, webMode; final List<String> webOff; }
class DemoOption { const DemoOption(this.id, this.label, this.choices); final String id, label; final List<String> choices; }
class HowToTest { const HowToTest({required this.setup, required this.steps, required this.expectProblem, required this.expectFixed,
    this.evidence = const [], this.codeRefs = const []}); }   // steps、evidence、codeRefs 是 List<String>，其餘 String
typedef DemoBodyBuilder = Widget Function(BuildContext context, DemoVariant variant, Widget webView, DemoWebController web);
typedef DemoToolbarBuilder = List<Widget> Function(BuildContext context, DemoWebController web);
class DemoSpec {
  const DemoSpec({required this.id, required this.title, required this.category, required this.fixSide, required this.confidence,
    required this.webPath, required this.howToTest, required this.configFor, this.platform = DemoPlatform.both,
    this.variants = kProblemFixed, this.options = const [], this.bodyBuilder, this.toolbarBuilder});
  final DemoWebViewConfig Function(String variantId, Map<String, String> options) configFor;
}
const kProblemFixed = [DemoVariant('problem', '問題版', webMode: 'problem'), DemoVariant('fixed', '修正版')];
// demo_catalog.dart
final List<DemoSpec> demoCatalog;      // 本任務先放空清單，後續任務逐步加入

// demo_scaffold.dart
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({super.key, required this.spec, required this.variant, required this.onVariantChanged,
    required this.title, required this.titleIsLiveRegion, required this.body,
    this.options = const {}, this.onOptionChanged, this.actions = const [], this.statusLine});
}
// home_page.dart
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.specs, this.pageBuilder});   // specs 預設 demoCatalog；pageBuilder 預設開 DemoPage。兩者都是為了測試可注入
  final List<DemoSpec>? specs; final Widget Function(DemoSpec spec)? pageBuilder;
}
// app.dart
class AppScope extends InheritedNotifier<AppSettings> { static AppScope of(BuildContext c); AppSettings get settings; LocalWebServer get server; Uri get webBase; }
```

- [ ] **Step 1: 寫失敗的測試**

```dart
// app_settings_test.dart（SharedPreferences.setMockInitialValues({})）
expect(AppSettings.parseExternalBase(''), isNull);
expect(AppSettings.parseExternalBase('   '), isNull);
expect(AppSettings.parseExternalBase('ftp://x'), isNull);
expect(AppSettings.parseExternalBase('192.168.1.10:8000').toString(), 'http://192.168.1.10:8000/');
expect(AppSettings.parseExternalBase('localhost:8000').toString(), 'http://localhost:8000/');   // 不能被當成 scheme 是 localhost
expect(AppSettings.parseExternalBase('http://10.0.2.2:8000/web').toString(), 'http://10.0.2.2:8000/web/');
expect(AppSettings.parseExternalBase('https://example.test/a/').toString(), 'https://example.test/a/');
// 預設值如上；setThemeMode(ThemeMode.dark) 後重新 load 仍是 dark；每個 setter 都會 notifyListeners

// demo_webview_config_test.dart
expect(effectiveTextScaleStrategy(TextScaleStrategy.webOwned, trustedPage: true), TextScaleStrategy.webOwned);
expect(effectiveTextScaleStrategy(TextScaleStrategy.webOwned, trustedPage: false), TextScaleStrategy.appOwned);
expect(effectiveTextScaleStrategy(TextScaleStrategy.appOwned, trustedPage: false), TextScaleStrategy.appOwned);
expect(effectiveTextScaleStrategy(TextScaleStrategy.none, trustedPage: false), TextScaleStrategy.none);
expect(DemoWebViewConfig.baseline.copyWith(passTheme: false).passTheme, false);
expect(DemoWebViewConfig.baseline.copyWith(passTheme: false).passLang, true);
```

`parseExternalBase` 的規則：去掉頭尾空白；不含 `://` 就補上 `http://`；scheme 必須是 http 或 https 且有 host；路徑結尾補 `/`；其餘回傳 null。

```dart
// demo_catalog_test.dart（對 demoCatalog 的結構檢查；清單為空時也要通過）
// - id 唯一，符合 ^[cabt]\d{2}$；category 和 id 開頭一致（c→contract、a→appOnly、b→boundary、t→tool）
// - File('assets/web/${spec.webPath}') 存在
// - variants 非空、id 唯一、webMode 是 'problem' 或 'fixed'
// - 每個 variant.webOff 的名稱都出現在該網頁檔的 data-fixes="…" 裡（讀檔用正則取出）
// - howToTest.steps 非空；setup、expectProblem、expectFixed 非空字串
// - confidence == observation 的頁面，evidence 非空

// demo_scaffold_test.dart（body 用 Text('BODY') 當替身）
// - 兩個變體 → 兩個 ChoiceChip，文字為「問題版」「修正版」；點「修正版」呼叫 onVariantChanged('fixed')
// - 單一變體 → 沒有 ChoiceChip
// - 顯示修正方（「修正在：App／網頁／兩邊／App 或網頁擇一」）與可信度（「已查證／需實機確認／觀察頁」）
// - titleIsLiveRegion 為 true 時，標題的語意節點帶 liveRegion 旗標；為 false 時不帶
//   （用安裝的 SDK 未棄用的 semantics matcher）
// - 「怎麼測」展開後看得到 setup、每一條 step、兩段預期、evidence

// home_page_test.dart（specs 傳入兩筆假的：一筆 contract、一筆 boundary；pageBuilder 回傳 Text('PAGE')）
// - 看得到分區標題「兩邊約定」「交界處限制」，且帶 header 語意；沒有資料的分區不顯示
// - 每列顯示大寫代號與標題
// - 點一列後畫面出現 'PAGE'
```

- [ ] **Step 2: 確認失敗**　Run: `flutter test`

- [ ] **Step 3: 實作**

`main.dart`：`WidgetsFlutterBinding.ensureInitialized()` → 載入 `SharedPreferences` 與 `AppSettings` → 建立並啟動 `LocalWebServer(loader: rootBundleLoader())` → `runApp`。`app.dart`：`MaterialApp`（`themeMode` 來自設定、淺色與深色主題、`flutter_localizations` 的 delegates、`supportedLocales` 為 `zh_TW` 與 `en`）；`WidgetsBindingObserver` 在 `resumed` 時呼叫 `server.ensureRunning()`。`AppScope.webBase`：內建時是 `server.baseUri`；外部時是 `parseExternalBase(externalBaseUrl)`，解析不出來就退回內建。

`HomePage`：依類別分四區，區名為「兩邊約定」「App 單方處理」「交界處限制」「工具」（標題用 `Semantics(header: true)`），每列顯示代號、標題、修正方、可信度、平台。`SettingsPage`：網頁來源（外部網址輸入要經過 `parseExternalBase`，不合法顯示錯誤文字）、App 主題、Android 顯示模式（只在 Android 顯示）。`DemoScaffold` 的變體選擇用一排可換行的 `ChoiceChip`。

- [ ] **Step 4: 確認通過並 commit**

```bash
git add -A && git commit -m "feat(app): settings, catalog model, home and demo scaffold"
```

---

### Task 5: DemoWebView 與第一個完整切片（C01 字體大小）

**Files:**
- Create: `lib/webview/demo_webview.dart`、`lib/webview/platform_webview.dart`、`lib/widgets/demo_page.dart`、`web/pages/c01-text-scale.html`
- Modify: `lib/catalog/demo_catalog.dart`、`web/index.html`
- Test: `test/webview/snapshot_test.dart`

**Interfaces:**
- Consumes: Task 2–4 的全部介面
- Produces:

```dart
// demo_webview.dart
WebSettingsSnapshot snapshotOf(BuildContext context, DemoWebViewConfig config);
class DemoWebView extends StatefulWidget {
  const DemoWebView({super.key, required this.uri, required this.webBase, required this.config,
    required this.controller, required this.hybridComposition});
}
// platform_webview.dart
Widget buildPlatformWebViewWidget(WebViewController c, {required bool hybridComposition});
Future<void> applyAndroidTextZoom(WebViewController c, int percent);   // 非 Android 不做事
Future<void> applyIosTextSizeAdjust(WebViewController c, int percent); // 非 iOS 不做事；注入 documentElement.style.webkitTextSizeAdjust
// demo_page.dart
class DemoPage extends StatefulWidget { const DemoPage({super.key, required this.spec}); }
Future<void> openInAppBrowser(BuildContext context, Uri uri);          // 失敗時顯示 SnackBar
```

本任務的 `DemoWebView` 要做到：

- `JavaScriptMode.unrestricted`；用 `onPageStarted`／`onUrlChange` 追蹤目前頂層網址。
- 註冊 `A11yBridge` 頻道。**只有 `isTrustedPage(目前頂層網址, webBase)` 為 true 時**才把訊息交給 `BridgeMessage.parse`，結果更新 `DemoWebController`（`ReadyMessage` 更新 `webTitle`、`webContract`、`webCaps`；`RouteChangedMessage` 更新 `webTitle`）並送進 `messages`。
- 收到 `ReadyMessage` 後執行一次 `updateSettingsScript(目前的 snapshot)`。之後 `MediaQuery` 或主題改變使 `snapshotOf` 的結果不同時再執行。
- `onPageStarted`／`onPageFinished` 更新 `loading`。
- 字級：每次頂層網址改變時算 `effectiveTextScaleStrategy(config.textScale, trustedPage: …)`。`webOwned` → Android `applyAndroidTextZoom(100)`。`appOwned` → Android `applyAndroidTextZoom(倍率×100)`，iOS 在 `onPageFinished` 後 `applyIosTextSizeAdjust(倍率×100)`；字級改變時重做。`none` → 都不做。
- 其餘旗標（返回、載入與錯誤、對話框、連結、縮放）在 Task 7–8 接上。

`DemoPage`：持有變體與選項的狀態；用 `buildDemoUri` 組網址（`webMode`、`webOff` 來自變體）；`DemoWebView` 的 `key` 包含變體、選項和顯示模式（任何一項改變就重建 WebView）。顯示模式是 `config.androidHybridComposition ?? settings.androidHybridComposition`。AppBar 標題：`titleFromWeb` 為 true 且網頁已回報時用 `webTitle`，為 true 但尚未回報時用 `spec.title`，為 false 時固定顯示「WebView 範例」。AppBar 的動作按鈕都有 tooltip：「用 In-app browser 開啟本頁」、「重新載入」（`web.reload()`）、「設定」，後面再接 `spec.toolbarBuilder` 提供的按鈕。

`openInAppBrowser`：`launchUrl(uri, mode: LaunchMode.inAppBrowserView)`；回傳 false 或丟例外時顯示 SnackBar：「無法用 In-app browser 開啟。內建網頁可能無法從瀏覽器存取，請到設定改用外部網頁來源。」AppBar 那顆按鈕開的是 `buildDemoUri(..., embedded: false)` 且不帶設定參數的網址。

- [ ] **Step 1: 寫失敗的測試**

```dart
// snapshot_test.dart：在 MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(1.3), boldText: true,
//   highContrast: true, disableAnimations: true)) 與深色 Theme、Localizations(zh_TW) 之下
// baseline → WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3, bold: true, contrast: true, reduceMotion: true)
// copyWith(textScale: TextScaleStrategy.none)      → textScale 為 null
// copyWith(textScale: TextScaleStrategy.appOwned)  → textScale 為 null
// copyWith(passTheme: false)                        → theme 為 null
// copyWith(passA11yPrefs: false)                    → bold、contrast、reduceMotion 為 null
// copyWith(passLang: false)                         → lang 為 null
// copyWith(langOverride: 'en')                      → lang 為 'en'
// textScaler 為 linear(5.0) 時 baseline 的 textScale 為 3.0
// disableAnimations 為 false，但 tester.platformDispatcher.accessibilityFeaturesTestValue 的 reduceMotion 為 true
//   → reduceMotion 為 true
```

`reduceMotion` 的值是 `MediaQuery.disableAnimationsOf(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion`。`textScale` 是 `normalizeTextScale(MediaQuery.textScalerOf(context).scale(16) / 16)`。

- [ ] **Step 2: 確認失敗**　Run: `flutter test test/webview`

- [ ] **Step 3: 實作 `demo_webview.dart`、`platform_webview.dart`、`demo_page.dart`**

`buildPlatformWebViewWidget`：平台是 `AndroidWebViewController` 時用 `WebViewWidget.fromPlatformCreationParams(params: AndroidWebViewWidgetCreationParams(controller: c.platform, displayWithHybridComposition: hybridComposition))`，否則 `WebViewWidget(controller: c)`。

- [ ] **Step 4: 寫 `c01-text-scale.html` 並加入目錄**

`data-fixes="textScale"`。內容依設計文件 §7 C01。類別 contract、修正方 both、可信度 verified。

| 變體 id | 標籤 | webMode | config |
|---|---|---|---|
| `problem` | 問題版 | problem | `baseline.copyWith(textScale: TextScaleStrategy.none)` |
| `fixed` | 修正版 | fixed | `baseline` |
| `app-only` | 只改 App | problem | `baseline.copyWith(textScale: TextScaleStrategy.appOwned)` |

- [ ] **Step 5: 同步並跑全部測試**

Run: `tool/sync_web.sh && flutter test && flutter analyze`

- [ ] **Step 6: 模擬器冒煙測試**

Run: `flutter run -d <ENVIRONMENT.md 記錄的模擬器>`
Expected: 首頁出現 C01；進入後網頁載入、AppBar 標題變成網頁的標題（代表 Bridge 通了）、三個變體可切換；系統字級調大後，修正版網頁文字變大。按一次「用 In-app browser 開啟本頁」，把結果記進 `ENVIRONMENT.md`。iOS 上若網頁載入失敗（ATS），**先停下來**把錯誤訊息記下並回報。

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: DemoWebView baseline and C01 text scale demo"
```

- [ ] **Step 8: 實機檢查點（停下來等使用者）**

先完成這個任務的逐任務審查，必修項目修完後才進行這一步。

所有報讀器行為都還沒在實機驗證過，後面 22 頁都建立在這一層上。請使用者用 `flutter run --profile -d <實機>` 安裝到手機（iOS 需要使用者自己處理簽署），確認下列項目後回報，**通過才繼續 Task 6**：

1. 內建網頁在實機載入得到（Android 和 iOS 各自）。
2. AppBar 標題會變成網頁的標題。
3. 開著 TalkBack／VoiceOver，可以從 AppBar 滑進網頁內容、再滑回來。
4. C01 三個變體在調大系統字級後的表現，是否符合頁面上「怎麼測」寫的預期。
5. 「用 In-app browser 開啟本頁」是開得了，還是顯示提示。

有任何一項和預期不同，先依結果修正設計文件和本計畫，再往下做。

---

### Task 6: 系統設定同步（C02、C03、C04、T01）

**Files:**
- Create: `web/pages/c02-theme.html`、`c03-a11y-prefs.html`、`c04-lang.html`、`t01-diagnostics.html`
- Modify: `lib/catalog/demo_catalog.dart`、`lib/widgets/demo_page.dart`（選項下拉選單）、`web/index.html`
- Test: `test/catalog/demo_catalog_test.dart`（加上 id 斷言）

**Interfaces:**
- Consumes: `snapshotOf`、`DemoOption`、`DemoSpec.configFor(variantId, options)`

| id | data-fixes | 修正方／可信度 | 變體與 config |
|---|---|---|---|
| `c02` | `theme` | both／needsDeviceTest | `problem`：`copyWith(passTheme: false)`；`fixed`：`baseline` |
| `c03` | `a11yPrefs` | both／needsDeviceTest | `problem`：`copyWith(passA11yPrefs: false)`；`fixed`：`baseline` |
| `c04` | `lang` | both／needsDeviceTest | 選項 `DemoOption('lang', 'App 語系（模擬）', ['zh-TW', 'en'])`。`problem`：`copyWith(passLang: false)`；`fixed`：`copyWith(langOverride: options['lang'])` |
| `t01` | （空） | none／verified | 單一變體 `DemoVariant('view', '檢視')`：`baseline` |

- [ ] **Step 1: 寫失敗的測試**：`demoCatalog` 的 id 包含 `c02`、`c03`、`c04`、`t01`；`c04` 有一個 id 為 `lang` 的選項。
- [ ] **Step 2: 確認失敗**　Run: `flutter test test/catalog`
- [ ] **Step 3: 寫四個網頁**（內容依設計文件 §7）。`c03` 的偏好判斷用 `A11yCore.resolvePref`。`t01` 的表格在 `onSettingsChanged` 和各 `matchMedia(...).addEventListener('change')` 時重畫；根字級顯示 `getComputedStyle(document.documentElement).fontSize`；`-apple-system-body` 的實際像素用一個套了 `font: -apple-system-body` 的隱藏元素量；約定版本與能力顯示 `A11yCore.CONTRACT_VERSION` 和目前啟用的修正清單。
- [ ] **Step 4: `DemoPage` 顯示選項**：`spec.options` 的每一項在變體列下方顯示一個有標籤的下拉選單，預設選第一個值，改變時重建 WebView。
- [ ] **Step 5: 加入目錄、同步、驗證**　Run: `tool/sync_web.sh && node ../web/test/run.mjs && flutter test && flutter analyze`；模擬器逐頁開啟每個變體。
- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: theme, a11y prefs, language demos and diagnostics page"
```

---

### Task 7: 結構與導覽（C05、C06、C07）

**Files:**
- Create: `web/pages/c05-title.html`、`c06-arrival.html`、`c07-back.html`
- Modify: `lib/webview/demo_webview.dart`、`lib/widgets/demo_page.dart`、`lib/catalog/demo_catalog.dart`、`web/index.html`
- Test: 目錄測試

**Interfaces:**
- Consumes: `decideBack`、`routeCanPop`、`jsCall`、`DemoWebController`、`CloseMessage`

| id | data-fixes | 修正方／可信度 | 變體（id／標籤／webMode／webOff）與 config |
|---|---|---|---|
| `c05` | `embeddedChrome embeddedTitle` | both／verified | `problem`／問題版／problem：`copyWith(titleFromWeb: false)` |
| | | | `fixed-app-title`／修正 A（AppBar 當標題）／fixed：`baseline` |
| | | | `fixed-web-title`／修正 B（網頁保留標題）／fixed，off `embeddedTitle`：`copyWith(titleFromWeb: false)` |
| `c06` | `arrival routeFocus` | either／needsDeviceTest | `problem`／問題版／problem：`baseline` |
| | | | `web-focus`／修正 A（網頁移焦點）／fixed：`baseline` |
| | | | `app-live`／修正 B（App liveRegion）／fixed，off `routeFocus`：`copyWith(arrival: ArrivalAnnounce.liveRegionTitle)` |
| | | | `app-announce`／修正 C（sendAnnouncement，僅 iOS）／fixed，off `routeFocus`：`copyWith(arrival: ArrivalAnnounce.sendAnnouncement)` |
| `c07` | `back` | both／needsDeviceTest | `problem`／問題版／problem：`copyWith(syncBackWithWeb: false)`；`fixed`／修正版／fixed：`baseline` |

要接上的行為（都在 `DemoPage`）：

- **抵達：** `arrival == liveRegionTitle` 時 `DemoScaffold.titleIsLiveRegion` 為 true，其餘為 false。`sendAnnouncement` 時，收到 `RouteChangedMessage` 就檢查 `MediaQuery.supportsAnnounceOf(context)`：true 則 `SemanticsService.sendAnnouncement(View.of(context), title, Directionality.of(context))`；false 則 `statusLine` 顯示「Flutter 在這個平台不支援 announcement，請用 liveRegion」。
- **返回：** `syncBackWithWeb` 為 true 時包 `PopScope(canPop: routeCanPop(...), onPopInvokedWithResult: …)`；`didPop` 為 false 時依 `decideBack`：`askWeb` → `runJavaScript(jsCall('handleBack'))`；`webHistoryBack` → `goBack()`；`popRoute` → `Navigator.pop`。`webCanGoBack` 在 `onUrlChange` 和 `onPageFinished` 時用 `canGoBack()` 更新；`webWantsBack` 來自 `BackStateMessage`。iOS 另外呼叫 `WebKitWebViewController.setAllowsBackForwardNavigationGestures(true)`。
- **關閉：** `syncBackWithWeb` 為 true 時，收到 `CloseMessage` 就 `Navigator.pop`；為 false 時忽略。

- [ ] **Step 1: 寫失敗的測試**：目錄的 id 包含 `c05`、`c06`、`c07`；`c05` 三個變體、`c06` 四個變體，id 如上表；`c06` 的 `app-live` 變體 `webOff` 為 `['routeFocus']`。
- [ ] **Step 2: 確認失敗**　Run: `flutter test test/catalog`
- [ ] **Step 3: 寫三個網頁**（依設計文件 §7）。`c06`、`c07` 用 `history.pushState` 與 `popstate`。`c07` 的對話框用 `<dialog>` 或 `role="dialog" aria-modal="true"`，開關時呼叫 `a11yApp.setBackState`，並用 `setBackHandler` 註冊關閉動作；「完成」按鈕在 `back` 啟用時呼叫 `a11yApp.requestClose()`，否則呼叫 `window.close()`。
- [ ] **Step 4: 接上上述行為**
- [ ] **Step 5: 加入目錄、同步、驗證**　Run: `tool/sync_web.sh && flutter test && flutter analyze`；模擬器上確認 C07 修正版的返回順序和「完成」會關閉頁面，C06 各變體的 AppBar 標題變化。
- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: title, arrival and back navigation demos"
```

---

### Task 8: App 接手的網頁功能與縮放（A01、A02、A03、C08）

**Files:**
- Create: `lib/contract/navigation_policy.dart`、`lib/widgets/web_error_view.dart`、`web/pages/a01-loading-error.html`、`a02-js-dialogs.html`、`a03-links.html`、`c08-zoom.html`
- Modify: `lib/webview/demo_webview.dart`、`lib/widgets/demo_page.dart`、`lib/catalog/demo_catalog.dart`、`web/index.html`
- Test: `test/contract/navigation_policy_test.dart`、`test/widgets/web_error_view_test.dart`、目錄測試

**Interfaces:**
- Produces:

```dart
// navigation_policy.dart
enum NavTarget { inWebView, externalApp, inAppBrowser }
NavTarget classifyNavigation(Uri target, Uri webBase);
String launchFailureMessage(Uri target);
bool shouldShowErrorView({required bool isForMainFrame, required int errorCode, required String? failingUrl,
    required Uri? currentTarget, required TargetPlatform platform});
// web_error_view.dart
class WebErrorView extends StatelessWidget { const WebErrorView({super.key, required this.description, required this.onRetry}); }
```

| id | data-fixes | 類別／修正方／可信度 | 變體與 config |
|---|---|---|---|
| `a01` | （空） | appOnly／app／verified | `problem`：`copyWith(accessibleLoadingAndError: false)`；`fixed`：`baseline`。`toolbarBuilder` 提供「慢速重新載入」「載入不存在的網址」 |
| `a02` | （空） | appOnly／app／verified | `problem`：`copyWith(handleJsDialogs: false)`；`fixed`：`baseline` |
| `a03` | （空） | appOnly／app／needsDeviceTest | `problem`：`copyWith(handleExternalNavigation: false)`；`fixed`：`baseline` |
| `c08` | `zoom` | contract／both／needsDeviceTest | `both-off`／兩邊都關（問題版）／problem：`copyWith(enableZoom: false)` |
| | | | `app-off`／只關 App／fixed：`copyWith(enableZoom: false)` |
| | | | `web-off`／只關網頁／problem：`baseline` |
| | | | `fixed`／都開（修正版）／fixed：`baseline` |

A01–A03 的 `data-fixes` 是空的，兩個變體的 `webMode` 都用 `fixed`。

- [ ] **Step 1: 寫失敗的測試**

```dart
final base = Uri.parse('http://127.0.0.1:8123/');
expect(classifyNavigation(Uri.parse('http://127.0.0.1:8123/pages/a.html'), base), NavTarget.inWebView);
expect(classifyNavigation(Uri.parse('http://127.0.0.1:9999/x'), base), NavTarget.inAppBrowser);   // 埠不同視為外部
expect(classifyNavigation(Uri.parse('https://example.com/'), base), NavTarget.inAppBrowser);
expect(classifyNavigation(Uri.parse('tel:+886212345678'), base), NavTarget.externalApp);
expect(classifyNavigation(Uri.parse('mailto:a@example.com'), base), NavTarget.externalApp);
expect(classifyNavigation(Uri.parse('about:blank'), base), NavTarget.inWebView);
expect(classifyNavigation(Uri.parse('data:text/html,hi'), base), NavTarget.inWebView);
expect(classifyNavigation(Uri.parse('blob:http://127.0.0.1:8123/abc'), base), NavTarget.inWebView);
expect(launchFailureMessage(Uri.parse('tel:123')), '這個裝置無法撥打電話');
expect(launchFailureMessage(Uri.parse('mailto:a@example.com')), '這個裝置沒有可用的郵件程式');
expect(launchFailureMessage(Uri.parse('myapp://x')), '無法開啟這個連結');

final target = Uri.parse('http://127.0.0.1:8123/pages/a01-loading-error.html?mode=fixed');
bool show({bool main = true, int code = -2, String? url, Uri? current, TargetPlatform p = TargetPlatform.android}) =>
    shouldShowErrorView(isForMainFrame: main, errorCode: code, failingUrl: url, currentTarget: current, platform: p);
expect(show(url: target.toString(), current: target), true);
expect(show(main: false, url: target.toString(), current: target), false);
expect(show(url: 'tel:+886212345678', current: target), false);                       // 非 http(s) 不取代
expect(show(url: 'http://127.0.0.1:8123/other.html', current: target), false);       // 不是目前的頂層目標
expect(show(url: '${target.toString()}#top', current: target), true);                // 只差 fragment 視為相同
expect(show(code: -999, url: target.toString(), current: target, p: TargetPlatform.iOS), false);  // 載入被取消
expect(show(code: 102, url: target.toString(), current: target, p: TargetPlatform.iOS), false);   // frame load interrupted
expect(show(url: null, current: target), true);
expect(show(url: null, current: null), false);

// web_error_view_test.dart
// - 有一個帶 header 語意的標題「網頁載入失敗」；顯示傳入的 description
// - 有「重試」按鈕，點擊後 onRetry 被呼叫一次
// 目錄測試：id 包含 a01、a02、a03、c08；c08 有四個變體
```

- [ ] **Step 2: 確認失敗**　Run: `flutter test`
- [ ] **Step 3: 實作 `navigation_policy.dart` 與 `WebErrorView`**
- [ ] **Step 4: 在 `DemoWebView`／`DemoPage` 接上四個旗標**
  - `accessibleLoadingAndError`：為 true 時，載入中在 `statusLine` 顯示 `Semantics(liveRegion: true)` 的「網頁載入中」；這次載入超過 1 秒時，完成後顯示「網頁載入完成」3 秒。`onWebResourceError` 時用 `shouldShowErrorView` 判斷（`currentTarget` 是最近一次頂層導覽的網址），為 true 才設 `mainFrameFailed`，`DemoPage` 改顯示 `WebErrorView`（不建立 WebView）。為 false 時只有 `LinearProgressIndicator`，錯誤時維持 WebView 自己的畫面。
  - A01 的按鈕：「慢速重新載入」在內建來源時載入 `buildDemoUri(同樣的參數, extraQuery: {'__delay': '3000'})`，外部來源時做一般重新載入並用 SnackBar 說明；「載入不存在的網址」載入 `http://127.0.0.1:9/missing`。
  - `handleJsDialogs`：呼叫 `setOnJavaScriptAlertDialog`、`setOnJavaScriptConfirmDialog`、`setOnJavaScriptTextInputDialog`，分別顯示 Flutter 的 `AlertDialog`（確定）、確認對話框（取消／確定，回傳 bool）、含 `TextField` 的對話框（回傳字串，取消回傳空字串）。為 false 時三個都不呼叫。
  - `handleExternalNavigation`：`onNavigationRequest` 依 `classifyNavigation`：`inWebView` → `navigate`；`externalApp` → `launchUrl(mode: LaunchMode.externalApplication)`，回傳 false 或丟例外時用 SnackBar 顯示 `launchFailureMessage`，然後 `prevent`；`inAppBrowser` → `openInAppBrowser`，然後 `prevent`。為 false 時不設定 `onNavigationRequest`。兩種請求一律 `navigate`、不分類：`request.isMainFrame` 為 false 的；以及 App 自己發起的載入（官方文件說有些平台會讓 `loadRequest` 也觸發這個回呼，所以 `loadUri` 要記下目標網址，回呼裡比對相同就放行，A01 的「載入不存在的網址」才不會被攔掉）。
  - `enableZoom`：`controller.enableZoom(config.enableZoom)`。
- [ ] **Step 5: 寫四個網頁**（依設計文件 §7）。`c08` 在 `zoom` 修正關閉時，由 `a11y-app.js` 載入階段把 viewport 改成 `width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no`。
- [ ] **Step 6: 加入目錄、同步、驗證**　Run: `tool/sync_web.sh && flutter test && flutter analyze`；模擬器上確認 A01 兩個按鈕的結果、A03 問題版點 `tel:` 後看到的是 WebView 自己的畫面而不是 `WebErrorView`。
- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: loading/error, JS dialogs, external links and zoom demos"
```

---

### Task 9: 雙向動作與版面（C09、C10、C11）

**Files:**
- Create: `lib/demos/layouts.dart`、`web/pages/c09-native-dialog.html`、`c10-native-submit.html`、`c11-safe-area.html`
- Modify: `lib/widgets/demo_page.dart`、`lib/catalog/demo_catalog.dart`、`web/index.html`
- Test: `test/demos/layouts_test.dart`、目錄測試

**Interfaces:**
- Produces:

```dart
String formResultText(FormResultMessage m);
Widget nativeSubmitBody(BuildContext context, DemoVariant variant, Widget webView, DemoWebController web);   // C10
Widget safeAreaBody(BuildContext context, DemoVariant variant, Widget webView, DemoWebController web);       // C11
```

每個 bodyBuilder 回傳的最外層元件都帶 `key: const Key('demo-body')`，測試用它限定搜尋範圍。

| id | data-fixes | 修正方／可信度 | 變體（id／標籤／webMode／webOff） | Flutter 端差異 |
|---|---|---|---|---|
| `c09` | `dialogReturn` | both／needsDeviceTest | `problem`、`fixed`，config 都是 `baseline` | 無（差異在網頁） |
| `c10` | `formErrors formFeedback` | either／needsDeviceTest | `problem`／問題版／problem | 不顯示結果 |
| | | | `web-handled`／修正 A（網頁處理）／fixed | 不顯示結果 |
| | | | `app-live`／修正 B（App liveRegion）／fixed，off `formFeedback` | 顯示 `liveRegion` 的結果文字 |
| `c11` | `safeArea` | both／observation | `none`／都不處理／problem | 不包 `SafeArea` |
| | | | `app-only`／只改 App／problem | `SafeArea(top: false)` 包住 WebView |
| | | | `web-only`／只改網頁／fixed | 不包 `SafeArea` |
| | | | `both`／兩邊都做／fixed | `SafeArea(top: false)` 包住 WebView |

- **C09（`DemoPage`，所有頁面通用）：** 收到 `OpenNativeDialogMessage` 時 `showDialog` 一個 `AlertDialog`（標題、內文、每個 action 一個按鈕），關閉後 `runJavaScript(jsCall('onNativeDialogClosed', [requestId, 選到的 action 或 'dismissed']))`。
- **C10：** `Column`：`Expanded(webView)`、結果文字、`FilledButton('送出')`。按鈕執行 `jsCall('submitForm')`。結果文字只在變體 id 為 `app-live` 時顯示，監聽 `web.messages` 裡的 `FormResultMessage`。
- C11 的 `evidence` 填「WCAG 2.2 2.4.11 焦點不被遮蔽」。

- [ ] **Step 1: 寫失敗的測試**

```dart
expect(formResultText(const FormResultMessage(ok: true, errorCount: 0)), '已送出');
expect(formResultText(const FormResultMessage(ok: false, errorCount: 2, firstError: '請輸入姓名')), '有 2 個欄位需要修正：請輸入姓名');
// nativeSubmitBody（webView 用 Text('WEB') 替身；web 用繼承 DemoWebController、會記錄 runJavaScript 引數的假物件）：
// - 有「送出」按鈕；點擊後假物件記錄到的 JS 是 jsCall('submitForm')
// - app-live 變體：addMessage(FormResultMessage(ok:false, errorCount:2, firstError:'請輸入姓名')) 後，
//   畫面出現「有 2 個欄位需要修正：請輸入姓名」且該節點帶 liveRegion 旗標
// - problem 與 web-handled 變體：送入同樣訊息後，畫面沒有該文字
// safeAreaBody：app-only 與 both 變體，Key('demo-body') 之下 webView 的祖先有 SafeArea；none 與 web-only 沒有
// 目錄測試：id 包含 c09、c10、c11；c11 的 confidence 是 observation 且有四個變體
```

- [ ] **Step 2: 確認失敗**
- [ ] **Step 3: 實作 `layouts.dart` 的三個函式與 `DemoPage` 的對話框處理**
- [ ] **Step 4: 寫三個網頁**（依設計文件 §7）。`c09` 用 `setDialogHandler`，`c10` 用 `setSubmitHandler`。
- [ ] **Step 5: 加入目錄、同步、驗證**　Run: `tool/sync_web.sh && flutter test && flutter analyze`
- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: native dialog, native submit and safe area demos"
```

---

### Task 10: App 的包法與版面（A04、A05、B01、B03）

**Files:**
- Modify: `lib/demos/layouts.dart`、`lib/catalog/demo_catalog.dart`
- Test: `test/demos/layouts_test.dart`、目錄測試

**Interfaces:**
- Produces（都符合 `DemoBodyBuilder`，最外層帶 `Key('demo-body')`）：`wrapperBody`（A04）、`coveredBody`（A05）、`overlayButtonBody`（B01）、`scrollableBody`（B03）

四頁的 `webPath` 都是 `pages/b-content.html`，`webMode` 都是 `fixed`，可信度都是 needsDeviceTest。

| id | 類別／平台 | 變體（id／標籤） | 版面與 config |
|---|---|---|---|
| `a04` | appOnly／both | `exclude`／ExcludeSemantics（問題版） | `ExcludeSemantics(child: webView)` |
| | | `ignore-pointer`／IgnorePointer（問題版） | `IgnorePointer(child: webView)` |
| | | `none`／無包裝（修正版） | `webView` |
| `a05` | appOnly／both | `overlay`／遮罩（問題版） | `Stack`：webView＋不透明的「維護中」畫面（文字與「重新整理」按鈕） |
| | | `overlay-blocked`／修正 A（BlockSemantics） | 同上，遮罩外包 `BlockSemantics` |
| | | `replaced`／修正 B（不建立 WebView） | 只有「維護中」畫面 |
| | | `indexed-stack`／觀察（隱藏分頁） | `SegmentedButton`（「Flutter 分頁」「網頁分頁」）＋兩個分頁的 `IndexedStack`；預設停在 Flutter 分頁 |
| `b01` | boundary／android | `tlhc`／問題版（TLHC） | `Stack`：WebView 上疊 `FloatingActionButton.extended(label: '回到頂端')`；`copyWith(androidHybridComposition: false)` |
| | | `hc`／修正 A（Hybrid Composition） | 同上版面；`copyWith(androidHybridComposition: true)` |
| | | `no-overlay`／修正 B（版面避開） | `Column`：`Expanded(webView)`＋底部列放同一個按鈕；`androidHybridComposition: false` |
| `b03` | boundary／both | `in-list`／問題版 | `ListView`：說明卡片、`SizedBox(height: 600, child: webView)`、兩個 Flutter 按鈕 |
| | | `fixed-layout`／修正版 | `Column`：說明卡片、`Expanded(webView)` |

B01 的 `toolbarBuilder` 提供「開啟對話框」（有兩個按鈕的 `AlertDialog`）和「開啟底部選單」（`showModalBottomSheet`，內含兩個按鈕）。「回到頂端」執行 `web.runJavaScript('window.scrollTo(0,0)')`。

- [ ] **Step 1: 寫失敗的測試**（`webView` 用 `Semantics(label: 'WEB', child: SizedBox.expand())` 當替身，`tester.ensureSemantics()`；所有搜尋都限定在 `Key('demo-body')` 之下）

```dart
// wrapperBody：'exclude' → find.bySemanticsLabel('WEB') 找不到；'none' 與 'ignore-pointer' → 找得到一個
// coveredBody：'overlay' → 找得到 'WEB'，也找得到「重新整理」
//              'overlay-blocked' → 找不到 'WEB'，找得到「重新整理」
//              'replaced' → 找不到 'WEB'
//              'indexed-stack' → 一開始找不到 'WEB'；點「網頁分頁」後找得到
// overlayButtonBody：'tlhc' 與 'hc' → demo-body 之下有一個 Stack 同時是「回到頂端」和 'WEB' 的祖先；'no-overlay' → 沒有這樣的 Stack
// scrollableBody：'in-list' → 'WEB' 的祖先有 ListView；'fixed-layout' → 沒有
// 目錄測試：id 包含 a04、a05、b01、b03；b01.platform == DemoPlatform.android
```

這些測試驗證的是 Flutter 語意樹的機制。原生 WebView 的實際表現仍須實機確認。

- [ ] **Step 2: 確認失敗**
- [ ] **Step 3: 實作四個 bodyBuilder，加入目錄**（`HowToTest` 依設計文件 §7，`evidence` 填 §4 的 issue 編號；B01 的步驟要包含對話框和底部選單，並註明用 profile 或 release 建置測）
- [ ] **Step 4: 驗證**　Run: `flutter test && flutter analyze`；Android 模擬器上確認 B01 三個變體與設定頁的顯示模式切換都能載入。
- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: wrapper, covered, overlay and scrollable demos"
```

---

### Task 11: 觀察頁、對照頁與工具（B02、B04、B05、T02）

**Files:**
- Modify: `lib/demos/layouts.dart`、`lib/catalog/demo_catalog.dart`
- Test: `test/demos/layouts_test.dart`、目錄測試

**Interfaces:**
- Produces（都符合 `DemoBodyBuilder`，最外層帶 `Key('demo-body')`）：`focusRestoreBody`（B04）、`keyboardBody`（B05）、`inAppBrowserBody`（T02）

四頁的 `webPath` 都是 `pages/b-content.html`。

| id | 類別／可信度 | 變體 | 內容 |
|---|---|---|---|
| `b02` | boundary／observation | `observe`／觀察 | 標準頁面。`HowToTest.steps` 是設計文件 §7 B02 的八條觀察清單。`toolbarBuilder` 提供「更新網頁的 aria-live 區域」，執行 `document.getElementById('live-status').textContent = '已更新 ' + new Date().toLocaleTimeString()` |
| `b04` | boundary／needsDeviceTest | `default`／預設行為；`restore`／復原焦點 | `focusRestoreBody`：說明文字、「開啟 WebView 頁」（key `open-web`）、「開啟純 Flutter 頁」（key `open-flutter`）。各自 push 一個有 AppBar 的全螢幕頁面，內容分別是傳入的 `webView` 和一段 Flutter 文字加按鈕 |
| `b05` | boundary／observation | `observe`／觀察 | `keyboardBody`：`TextField(labelText: 'Flutter 輸入框')`、`Expanded(webView)`、`FilledButton('Flutter 按鈕')` |
| `t02` | tool／verified | `view`／檢視 | `inAppBrowserBody`：說明文字（設計文件 §7 T02 的取捨）、「用 In-app browser 開啟」（`openInAppBrowser`）、「用 WebView 開啟同一頁」（push B02 的 `DemoPage`） |

**B04 的復原時機：** 用自己建立的 `MaterialPageRoute`，`await Navigator.push(route)` 之後再 `await route.completed`（轉場動畫結束），然後在下一個 frame 對剛才按的按鈕的 render object 呼叫 `sendSemanticsEvent(const FocusSemanticEvent())`。只有 `restore` 變體做這件事。

- [ ] **Step 1: 寫失敗的測試**

```dart
// focusRestoreBody（tester.ensureSemantics()；webView 用 Text('WEB') 替身；
//   用 tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(SystemChannels.accessibility, …) 收集語意事件）
// - restore 變體：點「開啟純 Flutter 頁」、pop、pumpAndSettle 後，收到一則 type == 'focus' 的事件，
//   且 nodeId 等於 tester.getSemantics(find.byKey(const Key('open-flutter'))).id
//   （不相等代表事件送到了祖先節點，要把送事件的 render object 改成擁有該按鈕語意節點的那一個）
// - restore 變體：改點「開啟 WebView 頁」同樣流程，nodeId 等於 open-web 按鈕的節點 id
// - default 變體：同樣流程後沒有收到 'focus' 事件
// keyboardBody：tester.semantics.simulatedAccessibilityTraversal() 的順序是 Flutter 輸入框 → 'WEB' → Flutter 按鈕
//   （webView 替身用 Semantics(label: 'WEB')）
// 目錄測試：demoCatalog.length == 23；contract 11、appOnly 5、boundary 5、tool 2；
//   b02、b05、c11 的 confidence 是 observation
```

- [ ] **Step 2: 確認失敗**
- [ ] **Step 3: 實作並加入目錄**
- [ ] **Step 4: 驗證**　Run: `flutter test && flutter analyze`；模擬器上逐頁開啟。
- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: observation, focus-restore comparison and in-app browser pages"
```

---

### Task 12: 文件與整體驗證

**Files:**
- Create: `README.md`、`docs/CONTRACT.md`
- Test: `flutter_app/test/readme_test.dart`

- [ ] **Step 1: 寫失敗的測試**：`../README.md` 包含 `demoCatalog` 每一筆的 id（大寫，如 `C01`）和標題。
- [ ] **Step 2: 寫 `README.md`**
  章節：這是什麼；環境需求；啟動（`cd flutter_app && flutter run`）；**用報讀器測試時要用 `flutter run --profile` 或 `--release` 裝到實機**（debug 版慢，行為也可能不同）；改用外部網頁來源（`cd web && python3 -m http.server 8000`，實機與模擬器各要填什麼網址）；修改網頁後要跑 `tool/sync_web.sh`；怎麼用（開報讀器、切換變體、看「怎麼測」、Android 可到設定切換顯示模式重測）；三種類別的意思；23 頁總表（代號、標題、類別、修正方、可信度、平台、依據）；每頁的測試步驟與預期；列出但未示範的項目（設計文件 §4.5）；已知限制（報讀器行為未經自動驗證、需實機確認的項目、明文 HTTP 與內建伺服器僅供示範）。
- [ ] **Step 3: 寫 `docs/CONTRACT.md`**：設計文件 §6 的獨立版本，給網頁團隊看：參數表（標明 `mode`、`off` 是範例專用）、字級責任歸屬、兩個方向的呼叫與訊息、朗讀由誰負責、信任範圍、約定版本與能力，每一項附上範例裡的程式位置。
- [ ] **Step 4: 全部自動檢查**

Run: `cd flutter_app && tool/sync_web.sh && flutter analyze && flutter test && node ../web/test/run.mjs`
Expected: 零問題、全過、`ALL PASS (24)`。

- [ ] **Step 5: 建置**

Run: `flutter build apk --debug`、`flutter build ios --simulator --debug`（只跑 `ENVIRONMENT.md` 記錄可用的平台）
Expected: 都成功。

- [ ] **Step 6: 模擬器冒煙測試**

啟動 App，截圖首頁、C01 修正版、T01。逐一開啟 23 頁的每個變體，確認都載入得到網頁、沒有例外。把無法在模擬器確認的項目列進 README 的已知限制。

- [ ] **Step 7: Commit 並交付**

```bash
git add -A && git commit -m "docs: README, contract reference and final verification"
```

這個任務同樣要做逐任務審查。之後再派一個獨立代理做整體審查：範圍是整個專案，重點是跨任務的一致性（介面有沒有在後面的任務被悄悄改掉、基準修正有沒有互相干擾、README 和 `CONTRACT.md` 是否和程式一致）。

回報時明確區分：自動檢查通過的項目、模擬器上看過的項目、**必須由使用者在實機用報讀器確認的項目**（全部 23 頁的無障礙行為），並附上 `docs/REVIEW_LOG.md` 的摘要。
