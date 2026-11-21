# 交接說明：換電腦接續執行

## 目前狀態

停下來的時間：2026-11-21，停在 Task 1 和 Task 2 的邊界。

| 項目 | 內容 |
|---|---|
| 已完成 | Task 0（環境檢查、版控）、Task 1（網頁核心，已通過逐任務審查） |
| 下一個任務 | Task 2（Flutter 專案與純 Dart 約定層）。還沒有執行 `flutter create`，`flutter_app/` 不存在 |
| Task 1 最後一個程式 commit | `cd6272f` |
| 審查紀錄與環境註記的 commit | `d2ef5d9` |
| 這份交接文件 | `main` 上的最新 commit |
| 還沒做的任務 | Task 2 到 Task 12、整體審查、Task 5 的實機檢查點 |

注意：Task 0 的環境檢查是在原本的電腦上做的，那台沒有 Android SDK。換電腦後要重做。

### Task 1 審查結果摘要

- 實作：Fable 5.2、xhigh。審查：Opus 5.5、high 的獨立代理。
- 審查結論：規格符合、品質通過。必修 0 項、應修 3 項、可之後再做 5 項。
- 採納並修正的三項：測試執行器在 0 條斷言時誤報通過；`ready` 握手不該被 `arrival` 修正關掉；`overflow-wrap` 的舊版 iOS 備援。同一個審查代理複查後通過，沒有新問題。
- 每一項發現、查證和處理方式都在 `docs/REVIEW_LOG.md`。

### 目前的驗證程度

| 層級 | 內容 |
|---|---|
| 自動檢查通過 | `node web/test/run.mjs` → `ALL PASS (68)` |
| 桌面瀏覽器上看過 | 網頁核心的執行期行為（主題、字級、header 隱藏、`ready` 與 `routeChanged`）。用的是桌面版 Chromium 和假的 Bridge，不是 WebView |
| 未驗證 | 所有報讀器行為；真正的 WebView 與真正的 `A11yBridge`；Android 的一切建置與執行 |

### 接手時要知道的事

**計畫和設計文件在執行期間改過兩次，以 repo 裡現在的版本為準：**

- `0145063`：實作與審查的模型改成逐任務指定（使用者確認）。
- `230dab7`：`ready` 是握手，每一頁一律送，和任何修正無關；`arrival` 修正只控制網頁內換頁的回報。不在 App 內時，`routeFocus` 啟用就由焦點移動負責朗讀、不寫 `aria-live`，關閉才寫。

**網頁核心（`web/shared/a11y-app.js`）的約定，後面寫示範頁的任務都要照做。** 完整說明在該檔檔頭的註解，範本是 `web/pages/b-content.html`：

- `a11y-app.js` 的 `<script>` 放在 `<body>` 的最前面，不在 `<head>`。
- `reportRoute` 由核心依 `arrival` 把關，各頁可以無條件呼叫。`setBackState`、`requestClose`、`postToApp` 不看修正開關，要由各頁用 `a11yApp.fixEnabled()` 判斷。
- 呼叫 `reportRoute` 的頁面在換畫面後要自己把焦點移到新標題（除非該頁把 `routeFocus` 關掉），否則在一般瀏覽器裡換畫面不會被念出來。
- 核心不處理 `lang` 修正，由 C04 自己決定內容與 `<html lang>`。
- `a11yApp.params` 會被 `updateSettings` 就地更新。
- `ready` 的 `caps` 是全部 14 個修正名稱當中沒被關掉的那些，意思是「沒被關掉」，不是「這一頁有實作」。
- 問題版／修正版的切換連結只在該頁有宣告修正時顯示。
- `A11yCore` 比計畫多了六個成員：`FIX_NAMES`、`parseFixList`、`enabledFixes`、`normalizeSettings`、`buildSearch`、`routeReportAction`。

**計畫文字和現況的落差：** 計畫 Task 1 Step 4 和 Task 12 Step 4 的預期輸出寫 `ALL PASS (24)`，現在是 68 條，之後還會增加。以「全部通過，而且計畫的 24 條逐字存在」為準。

**前一位協調者在執行前掃描做的裁定**（Task 2 以後的都還沒用到，可以沿用或重新裁定）列在 `docs/REVIEW_LOG.md` 的「執行前掃描」一節。和 Task 2 到 Task 4 直接相關的有：

- Task 2：commit 時一併加入 `docs/ENVIRONMENT.md`（計畫的指令只有 `git add flutter_app`）。
- Task 3：同步腳本和 assets 同步測試都要排除 `.DS_Store`。
- Task 4：`HomePage` 預設的 `pageBuilder` 先用暫時頁面，Task 5 再換成 `DemoPage`；`DemoScaffold` 負責畫選項的下拉選單；`HomePage` 的 AppBar 也放「設定」按鈕；`DemoScaffold` 各欄位的型別見審查紀錄。

**留給後續任務的事項**（細節在 `docs/REVIEW_LOG.md` Task 1 的最後一節）：

- `window.a11yApp` 的執行期部分沒有自動測試，整體審查時判斷要不要補。
- 共用內容頁的三個頁內連結會增加瀏覽紀錄；Task 7 的返回同步上線後，按返回會先在頁內錨點之間退。用到這一頁的示範要在「怎麼測」註明。
- `base.css` 的 `:root` 設了 `color-scheme: light`，Android WebView 的自動調暗會不會受影響，要在 C02 的實機測試確認。

**沒有跟著 git 過來的東西：** 前一位協調者的進度帳本、派工用的共用規則檔、各任務的摘要與實作報告都放在不納入版控的 `.superpowers/` 裡。新 session 要自己重新建立；需要的事實都已寫在這份文件和 `docs/REVIEW_LOG.md`。

## 在新電腦上怎麼開始

1. `git clone https://github.com/zyzdev/a11y-webview-demo.git`
2. 用 Claude Code 開啟這個資料夾。模型 Fable 5.2、強度 xhigh、fast mode 關。
3. 把下面「給新 session 的指示」整段貼給它。

## 給新 session 的指示

請接續執行這個專案的實作計畫。和使用者溝通一律用繁體中文（台灣用語）。

**先讀完這五份文件**
- `docs/HANDOFF.md`（這份文件的「目前狀態」一節）
- `docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md`（設計文件，尤其 §5.2 基準原則、§6 約定、§7 各頁設計）
- `docs/superpowers/plans/2026-11-21-webview-a11y-demo.md`（實作計畫，尤其「執行方式」「Global Constraints」「執行流程」）
- `docs/ENVIRONMENT.md`、`docs/REVIEW_LOG.md`

**背景**
使用者的工作專案是一個要做無障礙的 Flutter App，裡面用 WebView 開了不少網頁。這個專案是給他在實機上用 TalkBack／VoiceOver 操作的範例：一個 Flutter App 加一個配合的網頁專案，共 23 個示範頁，每頁有問題版和修正版。規劃、查證和計畫審查都已完成。Task 0 和 Task 1 已在另一台電腦做完，那台沒有 Android SDK，所以換到這台有完整環境的電腦接著做。

**執行方式使用者已經確認，寫在計畫開頭，不需要再列評估表詢問**
- 以正確度為優先，不以省額度或省時間為考量。
- 你是協調者，不自己寫實作。Task 2 到 Task 12 每個任務派一個全新子代理實作，你自己看 diff 並重跑測試，再派另一個全新代理審查。實作和審查各用哪個模型與強度，依計畫「執行流程」裡的逐任務表（Task 5、7、8 用 Fable 5.2 xhigh 實作、Opus 5.5 high 審查；其餘用 Opus 5.5 high 實作、Fable 5.2 high 審查），每次派代理都明確指定。必修項目交回原本的實作代理修正，再由同一個審查代理複查，全部通過才進下一個任務；複查仍未通過時依計畫的升級規則處理。整體審查用 Fable 5.2 xhigh。
- 使用 superpowers:subagent-driven-development；這台電腦沒有這個 skill 的話，直接照計畫「執行流程」一節做。
- 每次審查的結果和處理方式記在 `docs/REVIEW_LOG.md`。
- 每個任務通過審查後執行 `git push origin main`。使用者已同意把這個專案放在這個 GitHub 私有庫。

**開始的順序**
1. 重做 Task 0 的環境檢查（`flutter --version`、`flutter doctor -v`、node、python3、iOS 模擬器、Android 模擬器），更新 `docs/ENVIRONMENT.md` 並 commit。git repo 已經存在，不用 `git init`。這台電腦預期有 Android SDK；有的話，之後每個任務的 Android 建置與模擬器驗證都要做，並把原本標成未驗證的 Android 項目補上結果。
2. 從 Task 2 接著做。

**一定要停下來回報的情況**
- 環境不符：`flutter` 不存在、版本低於 3.41.0，或 Android 和 iOS 工具鏈都不可用。不要自行安裝或升級任何東西。
- 計畫指定的 API 在安裝的 SDK 裡不存在，或計畫和實際情況對不上。不要自行換成別的 API 或改介面，先回報並提出建議。
- Task 5 的實機檢查點：審查通過後停下來，請使用者用實機確認計畫裡列的五個項目，通過才繼續 Task 6。
- 額度：每個任務開始前查一次方案用量。每週 Fable 或全模型剩不到 10% 時不開始新任務，停在任務邊界回報。不得為了額度降低模型或強度、跳過審查。

**完成的樣子**
- 做到 Task 12 並完成整體審查；或在上面任何一個停止點停下，清楚說明做到哪裡、下一步是什麼。
- 每次回報都明確區分：自動檢查通過的項目、在模擬器上看過的項目、必須由使用者在實機用報讀器確認的項目。測試失敗就附上實際輸出。
- 沒有任何報讀器行為在實機上驗證過，文件、頁面和回報都不得宣稱已驗證。
