# 交接說明：在另一個環境接續執行

最後更新：2026-11-22。這份文件是接續工作的入口：先讀「最新狀態」，再照「先完成的任務」和「後續任務」做。每個任務的審查細節在 [REVIEW_LOG.md](REVIEW_LOG.md)。

## 最新狀態

| 項目 | 內容 |
|---|---|
| 已完成 | Task 0、Task 1–5，都通過逐任務審查並 push。最後一個程式 commit 是 `b5b27a6`，之後只有文件 |
| 示範頁 | 1 / 23（C01 字體大小） |
| 停在哪裡 | **Task 5 的實機檢查點**（計畫 Task 5 Step 8）。使用者要在實機確認五個項目，通過才做 Task 6 |
| 自動檢查 | `flutter analyze` 零問題、`flutter test` 211 個全過、`node web/test/run.mjs` → `ALL PASS (68)`、Android debug APK 與 iOS 模擬器建置都成功 |
| 驗證程度 | 兩個平台的模擬器上看過 C01 的載入、Bridge、三個變體、大字級、信任判斷的各種導覽情境。**沒有任何報讀器行為在實機上驗證過** |
| 模型 | 2026-11-21 17:20 起，使用者決定「全部改用 Opus」（見下方「執行方式」）。要切回原本的模型表由使用者指示 |
| 設計變更 | Task 5 的審查發現 iOS 的 `onPageStarted` 在新頁面換上前就觸發。使用者核准修法後，設計文件 §6.1–§6.3 與計畫 Task 5 改成「已換上／載入中」的模型（commit `de0e874` 到 `470ad23`） |

## 先完成的任務

### 1. 在新環境重做環境檢查

照計畫 Task 0 的步驟檢查，再把結果寫進 [ENVIRONMENT.md](ENVIRONMENT.md)：在最前面加一節記錄新環境，第二台電腦的紀錄保留在後面。

- 執行 `flutter --version`、`flutter doctor -v`、`node --version`、`python3 --version`，並列出 iOS 模擬器與 Android 模擬器。
- **版本：** Flutter 要是 stable 3.41.0 以上。開發時用的是 3.47.5；版本不同時，先用 `flutter test` 與兩個平台的建置確認沒有退步。
- **Swift Package Manager：** 第二台電腦的 Flutter 設定關掉了 Swift Package Manager，所以 iOS 外掛走 CocoaPods（`ios/Podfile`、`Podfile.lock` 已納入版控）。新環境如果開著它，第一次建置時 Flutter 可能會自動改 Xcode 專案。建置後先看 `git status`，不要直接 commit 這類自動改動，先判斷要不要保留。
- **模擬器名稱：** 把 [handoff/verify.sh](handoff/verify.sh) 和 [handoff/implementer-rules.md](handoff/implementer-rules.md) 裡的模擬器名稱，改成新環境實際有的裝置。
- **環境不符就停下來回報：** `flutter` 不存在、版本太低、兩個平台的工具鏈都不能用時，停下來回報，不要自行安裝或升級。第二台電腦遇過 Flutter 設定指向不存在的 Android Studio，導致 `flutter doctor` 當掉；當時是使用者同意後才修的。

### 2. Task 5 的實機檢查點（使用者做）

用 profile 建置裝到手機（`cd flutter_app && flutter run --profile -d <裝置>`）。iOS 的簽署由使用者自己處理，步驟寫在 [README](../README.md)「用報讀器在實機上測試」。

| # | 要確認的事 | 模擬器上的結果 | 只有實機看得到的部分 |
|---|---|---|---|
| 1 | 內建網頁在實機載入得到（Android 與 iOS 各自） | 兩個平台都載入得到 | iOS 實機的 ATS 規則（Apple 文件說法不一致） |
| 2 | 進 C01 後，AppBar 標題變成「字體大小示範」 | 兩個平台都看到 | — |
| 3 | 開著 TalkBack／VoiceOver，可以從 AppBar 滑進網頁內容、再滑回來 | **模擬器做不到**（Android 模擬器沒有 TalkBack，iOS 模擬器不能執行 VoiceOver） | 全部 |
| 4 | 系統字級調大後，C01 三個變體的表現符合頁面上「怎麼測」的預期 | 兩個平台都符合 | Android 14 以上的非線性字級 |
| 5 | 「用 In-app browser 開啟本頁」開得了，還是顯示提示 | iOS 開得了；Android 卡在 Chrome 的首次啟動畫面（要同意 Chrome 的服務條款，代理沒有代為同意） | Android 的真正結果 |

- **全部通過：** 在 `REVIEW_LOG.md` 與 `ENVIRONMENT.md` 記下結果，接著開始 Task 6。
- **有項目和預期不同：** 先依結果修正設計文件與計畫，再往下做（計畫的規定）。如果需要改設計，先向使用者提出選項與建議。

## 後續任務

每個任務照「執行方式」的流程做。模型欄是目前的安排（全部 Opus）；括號裡是計畫原本的安排。

| 任務 | 內容 | 實作 | 審查 |
|---|---|---|---|
| 6 | C02 深淺色主題、C03 粗體／高對比／減少動態、C04 語系、T01 診斷對照表 | Opus high | Opus high（原 Fable high） |
| 7 | C05 標題與重複導覽、C06 頁面抵達、C07 返回與關閉 | Opus xhigh（原 Fable xhigh） | Opus high |
| 8 | A01 載入中與錯誤、A02 JS 對話框、A03 電話／信箱／外部連結、C08 縮放 | Opus xhigh（原 Fable xhigh） | Opus high |
| 9 | C09 原生對話框、C10 原生按鈕送出表單、C11 安全區域 | Opus high | Opus high（原 Fable high） |
| 10 | A04 外層包裝、A05 被遮住的 WebView、B01 疊加元件、B03 可捲動容器 | Opus high | Opus high（原 Fable high） |
| 11 | B02 焦點進出、B04 焦點復原、B05 外接鍵盤、T02 In-app browser | Opus high | Opus high（原 Fable high） |
| 12 | README 完整版、`docs/CONTRACT.md`、整體驗證 | Opus high | Opus high（原 Fable high） |
| 整體審查 | 整個專案，重點是跨任務的一致性 | — | Opus xhigh（原 Fable xhigh） |

### 寫示範頁時共用的約定（Task 6–11 都要帶進派工說明）

網頁端（完整說明在 `web/shared/a11y-app.js` 檔頭的註解，範本是 `web/pages/b-content.html` 與 `web/pages/c01-text-scale.html`）：

- `a11y-app.js` 的 `<script>` 放在 `<body>` 的最前面，不在 `<head>`。
- `reportRoute` 由核心依 `arrival` 修正把關，各頁可以無條件呼叫；`setBackState`、`requestClose`、`postToApp` 不看修正開關，要由各頁用 `a11yApp.fixEnabled()` 判斷。
- 呼叫 `reportRoute` 的頁面，換畫面後要自己把焦點移到新標題（除非該頁關掉 `routeFocus`）。
- 核心不處理 `lang` 修正，由 C04 自己決定內容與 `<html lang>`。
- `a11yApp.params` 會被 `updateSettings` 就地更新。
- `ready` 由核心在每一頁一律送出（握手），和修正無關；App 在需要時會呼叫 `reportReady()` 請網頁補送。
- 問題版／修正版的切換連結只在該頁有宣告修正時顯示。
- 改完 `web/` 要跑 `flutter_app/tool/sync_web.sh`。

App 端：

- 每一頁是 `lib/catalog/demo_catalog.dart` 裡的一筆 `DemoSpec`，寫法照 C01。問題版只用 `DemoWebViewConfig.baseline.copyWith(...)` 關掉該頁要示範的那一項（基準原則）。
- 需要特殊版面的頁面用 `bodyBuilder`，工具列按鈕用 `toolbarBuilder`；`DemoPage` 每次切換變體都會換一個新的 `DemoWebController` 並重建 WebView。
- `DemoWebView` 的信任判斷、字級、`reportReady` 都在 `lib/webview/demo_webview_logic.dart`，規則照設計文件 §6.3。新的行為（返回、錯誤畫面、導覽攔截）要接進這套狀態，不要另做一份。
- 「怎麼測」的註解與文字提到報讀器行為時，一律寫成預期或需實機確認。

### 各任務要帶進派工說明的事項

這些是前面的任務或審查留下來的決定與提醒。實作代理和審查代理只看得到計畫，所以要寫進派工說明。

**Task 6**
- 選項的下拉選單已經由 `DemoScaffold` 畫好（Task 4，裁定 P2），`DemoPage` 也已經先把每個選項填成第一個值（Task 5）。計畫 Step 4 的「`DemoPage` 顯示選項」只要確認 C04 用得上，不要重做一份。
- T01 單一變體，`expectProblem`、`expectFixed` 照實寫要觀察什麼（裁定 P8）。
- T01 顯示的「能力」來自 `ready` 的 `caps`，意思是「這一頁沒被關掉的修正」，不是「這一頁有實作的修正」。頁面文字要寫清楚（Task 1 審查第 5 項）。
- `base.css` 的 `:root` 設了 `color-scheme: light`，深色主題才切成 `dark`。Android WebView 的自動調暗會不會受影響，要列進 C02 的實機觀察項。

**Task 7**
- `goBack()`／`goForward()` 目前不算「App 發起的載入」：`DemoWebView` 只追蹤 `loadRequest` 與 `reload`，見 `lib/webview/demo_webview.dart` 與 `demo_webview_logic.dart`。返回同步會用 `goBack()`，要決定它是否一開始就記為載入中，並在兩個模擬器上確認返回的時序。iOS 從其他網域返回自家頁面（bfcache）時是以錯誤 -999 結束，現在靠「以最後回報的網址為準」才正確，不能動這條規則。
- 網頁呼叫 `reportRoute` 換畫面後，要自己把焦點移到新標題（除非該頁關掉 `routeFocus`）；`setBackState`、`requestClose`、`postToApp` 不看修正開關，要由各頁用 `a11yApp.fixEnabled()` 判斷（Task 1 的約定）。
- Bridge 訊息只在信任範圍內才處理（設計文件 §6.3）。網頁正在載入時送的 `backState`、`close` 可能被擋，C07 的流程要在模擬器上確認不受影響。
- C06 修正 C 的「Flutter 在這個平台不支援 announcement」顯示在 `statusLine`，頁框已經處理大字級下的高度（Task 4 第二、三輪修正）。
- 建議審查代理在兩個模擬器上實際走返回流程（第三步按返回、對話框開著按返回、按「完成」）。

**Task 8**
- 允許修改 `lib/webview/demo_web_controller.dart`（`loadUri` 要記下目標網址，這個檔案不在計畫的 Files 清單）。Task 5 已經有追蹤「App 發起的載入」的機制，沿用它，不要另做一套。
- `DemoWebView` 已經註冊 `onWebResourceError`，目前只用來結束載入中狀態。計畫的 `shouldShowErrorView` 要接在同一個地方，並和 `demo_webview_logic.dart` 的狀態整合（`currentTarget` 是最近一次頂層導覽的網址），不要再維護一份平行的狀態。
- 允許修改 `web/shared/a11y-app.js`，讓 `zoom` 修正關閉時改 viewport（裁定 P6），改完網頁自我測試要全過。
- AppBar 在大字級時標題已經會被截斷（Task 5 實作者的觀察），Task 8 再加工具列按鈕會更擠，要看大字級下的版面。
- Android 的 In-app browser 還沒確認（見檢查點第 5 項）。

**Task 9**
- 決定 `OpenNativeDialogMessage.actions` 的個數上下限：目前可以是空清單，也沒有上限（Task 2 審查第 2 項）。

**Task 10、Task 11**
- README 過渡版的示範頁一覽裡，B 類與 T 類頁面的「修正方」是協調者暫填的，`DemoSpec` 定案後要對齊。
- 用到 `b-content.html` 的示範要在「怎麼測」註明：頁內的三個錨點連結會增加瀏覽紀錄，返回同步上線後，按返回會先在錨點之間退（Task 1 審查第 6 項）。

**Task 12**
- 根目錄的 `README.md` 目前是過渡版（2026-11-22 由協調者寫，還沒經過審查）。Task 12 把它擴充成計畫要求的完整版，保留過渡版裡的實機安裝步驟、外部網頁來源、已知限制。`readme_test` 會檢查 README 包含每一頁的大寫代號與標題。
- `docs/CONTRACT.md` 要寫到：`caps` 的意思；App 會呼叫 `reportReady()`（設計文件 §6.2）；信任範圍的「已換上／載入中」規則與三條殘留風險（跨網域 iframe、`webBase` 路徑不是安全邊界、iOS「錯誤先到、網址變回後到」）。
- 計畫寫的 `ALL PASS (24)` 是舊數字，以「全部通過，而且計畫的 24 條逐字存在」為準。

### 延後處理的事項（整體審查要逐項判斷）

| 來源 | 事項 |
|---|---|
| Task 1 | `window.a11yApp` 的執行期部分沒有自動測試，只有 `A11yCore` 有 |
| Task 2 | `buildDemoUri` 遇到沒有結尾斜線的 base 會丟掉最後一段路徑（目前所有 base 都以 `/` 結尾） |
| Task 3 | 同步腳本遇到「來源已不存在、只剩 `.DS_Store` 的目的端目錄」，第一次執行會留下空目錄 |
| Task 4 | 伺服器錯誤說明需要捲動時沒有捲軸提示；`parseExternalBase` 接受 `:+80` 與帶帳號密碼的網址，國際化網域與帶 zone 的 IPv6 被拒時錯誤文字不對題；`\s` 檢查實際不會觸發；狀態列測試的「至少一行」門檻偏寬；PageDown 測試沒有斷言控制區真的捲動 |
| Task 5 | iOS 使用者在 In-app browser 載入完成前就關掉時，也會顯示「無法開啟」的提示 |

## 執行方式

和計畫「執行方式」「執行流程」相同，加上執行期間的決定：

- **協調者不自己寫實作。** 每個任務派一個全新的實作代理，派工說明包含：任務全文（從計畫摘出）、上面「要帶進派工說明的事項」、[handoff/implementer-rules.md](handoff/implementer-rules.md)、報告檔的路徑。
- **協調者自己查證：** 看 diff，跑 `zsh docs/handoff/verify.sh --launch`（analyze、test、網頁自我測試、assets 同步、兩個平台建置、在兩個模擬器上啟動）。代理的回報只是說法，不是證據。
- **審查：** 派一個全新的審查代理，只給設計文件路徑、計畫路徑與任務編號、commit 範圍、協調者補的決定，加上 [handoff/reviewer-rules.md](handoff/reviewer-rules.md)。不給實作者的報告。審查代理在 `git archive` 匯出的複本上做，可以用模擬器。
- **修正與複查：** 必修交回同一個實作代理（接續它），由同一個審查代理複查。協調者也會採納應修和便宜的可之後再做（使用者要求以正確度為優先）。每次審查的結果和處理都記進 `REVIEW_LOG.md`，任務通過後 `git push origin main`。
- **不要同時讓兩個實作代理改工作目錄。** 審查代理在匯出的複本上做，可以和下一個任務的實作同時進行。
- **模型：** 使用者在 2026-11-21 選了「全部改用 Opus」：實作、審查、複查都用 Opus 5.5，強度照原表（原本 Fable xhigh 的角色改成 Opus xhigh）。實作和審查同一個模型時，盲點容易重疊，所以審查代理要被明確要求以找錯為目標、重要結論都實際執行驗證。使用者要求切回原表時，照計畫的逐任務表。
- **額度：** 每個任務開始前查一次方案用量。每週任一額度剩不到 10% 時，不開始新任務，停下來回報。2026-11-21 晚上使用者放寬過一次門檻，只限那一晚。
- **一定要停下來回報的情況：** 環境不符；計畫指定的 API 不存在，或計畫和實際情況對不上（先回報並提出建議，不自行改做法）；Task 5 的實機檢查點；額度不足。
- **信任判斷：** 設計文件 §6.3 的信任判斷，在 Task 5 已經因為 iOS 的時序被找到三次漏洞。協調者答應過使用者：如果再被找到新的繞過路徑，先停下來討論是繼續補，還是在設計文件降低這一層的保證，不要自己再開一輪。

## 給新 session 的指示

把下面整段貼給新的 Claude Code session：

> 請接續執行這個專案的實作計畫。和使用者溝通一律用繁體中文（台灣用語）。先讀 `docs/HANDOFF.md`（整份），再讀 `docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md`、`docs/superpowers/plans/2026-11-21-webview-a11y-demo.md`（尤其「執行方式」「Global Constraints」「執行流程」）、`docs/ENVIRONMENT.md`、`docs/REVIEW_LOG.md`。
>
> 你是協調者，不自己寫實作，照 `docs/HANDOFF.md`「執行方式」做：每個任務派全新的實作代理與審查代理，每次都明確指定模型與強度，派工時附上 `docs/handoff/` 的規則檔與 HANDOFF 裡「要帶進派工說明的事項」。使用 superpowers:subagent-driven-development（如果有），規則以這份交接文件和計畫為準。
>
> 開始的順序：先做 HANDOFF「先完成的任務」第 1 項（新環境的環境檢查），然後等使用者回報 Task 5 實機檢查點的結果，通過才從 Task 6 開始。
>
> 每次回報都分清楚：自動檢查通過的、在模擬器上看過的、必須由使用者在實機用報讀器確認的。沒有任何報讀器行為在實機上驗證過，文件、頁面和回報都不得宣稱已驗證。

## 沒有跟著 git 過來的東西

- 第二台電腦的協調帳本 `.superpowers/sdd/2026-11-21-webview-a11y-demo/`（不納入版控）：每個代理的識別碼、每次派工訊息、實作報告。接手需要的事實都已寫進這份文件與 `REVIEW_LOG.md`；派工與審查的規則檔複製在 `docs/handoff/`。新 session 用 superpowers:subagent-driven-development 時會自己建立新的帳本。
- 模擬器上的截圖與測試用的外部伺服器腳本（放在暫存目錄）。

## 歷史

| 時間 | 地點 | 做了什麼 |
|---|---|---|
| 2026-11-21 白天 | 第一台電腦（沒有 Android SDK） | 規劃、計畫審查、Task 0、Task 1 |
| 2026-11-21 下午到晚上 | 第二台電腦（Mac mini） | 重做 Task 0；Task 2–5；17:20 起改用 Opus；Task 5 的設計變更 |
| 2026-11-22 | 第二台電腦 | 補上 README 過渡版；寫這份交接文件 |

各任務的實作者、審查者、發現與處理方式都在 [REVIEW_LOG.md](REVIEW_LOG.md)。
