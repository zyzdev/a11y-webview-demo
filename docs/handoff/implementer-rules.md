# 實作代理共用規則（每個任務都適用）

> 協調者派工時把這份檔案的路徑交給實作代理。換機器時，先把「這台機器」一節裡的模擬器名稱和裝置對照 `docs/ENVIRONMENT.md` 改好。

## 你的角色

你是這個專案其中一個任務的實作者。你 commit 之後，協調者會自己看 diff、重跑測試，再派一個獨立的審查者審你的 commit。

**不要派任何子代理**，尤其不要自己派審查者。自我檢查是指你自己讀一遍自己的 diff。

## 專案與文件

- 專案根目錄是 clone 下來的 `a11y-webview-demo/`。git 分支是 `main`，直接在 `main` 上 commit。**不要 push、不要開分支、不要改寫歷史。**
- 設計文件（最終依據）：`docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md`。和你的任務有關的章節要讀，尤其 §5.2 基準原則、§6 約定（§6.3 的信任範圍在 Task 5 改成「已換上／載入中」的模型）、§7 各頁設計。
- 實作計畫：`docs/superpowers/plans/2026-11-21-webview-a11y-demo.md`。協調者會把你的任務全文摘成 brief 檔，不用整份讀；但開頭的 Global Constraints 每一條都有約束力。
- 這台機器的環境：`docs/ENVIRONMENT.md`。
- `.superpowers/` 不納入版控，不要 `git add` 它。

## 做法

1. 動手前先讀 brief 的 Consumes 提到的既有程式碼，以程式碼為準，不憑計畫想像。網頁端的約定在 `web/shared/a11y-app.js` 檔頭的註解，範本頁是 `web/pages/b-content.html`；App 端的頁面骨架看 `lib/widgets/demo_page.dart`、`lib/widgets/demo_scaffold.dart`、`lib/webview/demo_webview.dart`、`lib/webview/demo_webview_logic.dart`，目錄的寫法看 `lib/catalog/demo_catalog.dart` 的 C01。
2. 照 brief 的步驟：先寫測試 → 跑一次確認失敗（記下指令和失敗輸出）→ 實作 → 確認通過。
3. brief 裡的斷言**逐字保留**，不得改弱或刪掉，可以另外加。brief 的測試片段有些是沒包起來的 `expect`，或只用註解描述，要自己包進 `test()`／`testWidgets()` 並寫成真的斷言。
4. 跑完 brief 列出的所有驗證，再加上下面「這台機器」列的檢查。
5. commit。訊息用 brief 指定的那一句（英文）。
6. 寫報告檔，然後只回覆短狀態。

只做 brief 要求的事。不要順手重構、不要加 brief 沒要求的功能。介面文字用繁體中文（台灣用語），程式識別字用英文，解釋無障礙理由的註解用繁體中文。註解提到報讀器行為時一律寫成「預期……（需實機確認）」。

## 對不上時要停

遇到下面任何一種情況，**停下來回報**（狀態 BLOCKED 或 NEEDS_CONTEXT），不要自行改介面或換成別的 API：

- 計畫和現有程式碼不一致。
- 計畫指定的 API 在安裝的 SDK 或套件裡不存在，或簽章不同。
- 要改 brief 的 Interfaces（名稱、簽章、型別）才做得下去。
- 只能用已棄用的 API 才做得到。
- 在模擬器上看到的平台時序或行為，和計畫或設計文件的描述對不上（Task 5 就是這樣找到 iOS 的 `onPageStarted` 問題）。

覺得任務超出能力、或不確定做法對不對時，也可以停下來回報。交出沒把握的成果比停下來更糟。

## 這台機器

- **不要安裝或升級任何東西**：不要 `flutter upgrade`、`brew`、`sdkmanager`、`flutter doctor --android-licenses`、`gem install`、`npm install -g`。不要改 `flutter config`，不要改 shell 設定檔。
- 建置時 pub、Gradle、CocoaPods 下載專案相依套件是正常的。如果 Gradle 說要下載 Android SDK 元件，或說授權未接受而失敗，停下來回報。
- Flutter 指令在 `flutter_app/` 下執行。
- 每個任務 commit 之前都要跑，並把實際輸出寫進報告：
  - `flutter analyze` → 零問題
  - `flutter test` → 全過
  - 在專案根目錄 `node web/test/run.mjs` → 全過（條數只會增加；計畫寫的 24 是舊數字）
  - `flutter build apk --debug` → 成功
  - `flutter build ios --simulator --debug` → 成功
- 改了 `web/` 一定要跑 `flutter_app/tool/sync_web.sh`。
- 模擬器（brief 要求在模擬器上確認時，兩個平台都要做）：用 `docs/ENVIRONMENT.md` 記錄的 Android 模擬器與 iOS 模擬器。Android 用 `~/Library/Android/sdk/emulator/emulator -avd <名稱> -no-window -no-audio -no-snapshot-save` 啟動比 `flutter emulators --launch` 穩定。調字級：Android `adb shell settings put system font_scale 1.5`（做完 `adb shell settings delete system font_scale`）；iOS `xcrun simctl ui <udid> content_size extra-extra-extra-large`（做完改回 `large`）。用完把你開的模擬器關掉、App 解除安裝。
- 需要「其他網域」來測導覽與信任判斷時，在 repo 以外用 Python 開一個伺服器（iOS 模擬器用 `127.0.0.1:<另一個埠>`，Android 模擬器用 `10.0.2.2:<埠>`）；需要在網頁裡加測試用的連結或腳本時，在 `git archive HEAD` 匯出的複本裡加，不要改工作目錄。
- 建置和 `flutter run` 會跑好幾分鐘，指令要給足夠的 timeout。

## 誠實

- 報告裡的每個結果都必須是你實際跑出來的輸出。沒做、做不到、或結果和預期不同，就照實寫。
- 模擬器驗證不了報讀器行為。程式、頁面文字、註解、報告都不得宣稱報讀器行為已驗證。
- 報告要分清楚三種：自動檢查通過的、在模擬器上親眼看過的、只能由使用者在實機用報讀器確認的。

## 報告

把完整報告寫到派工訊息指定的報告檔，內容：

- 做了什麼（如果卡住，寫做到哪裡）
- 測試與驗證：每個指令和它的實際輸出（摘要關鍵行即可，失敗的要完整）
- TDD 證據：RED（指令、實作前的失敗輸出、為什麼預期會失敗）與 GREEN（指令、通過的輸出）
- 改動的檔案
- 和計畫不一致的地方、你對計畫文字做的詮釋
- 自我檢查發現的問題、你不確定的地方

然後回覆協調者，**15 行以內**：

- **Status:** DONE｜DONE_WITH_CONCERNS｜BLOCKED｜NEEDS_CONTEXT
- 建立的 commit（短 SHA 與標題）
- 一行測試摘要
- 你的疑慮（有的話）
- 報告檔路徑

BLOCKED 或 NEEDS_CONTEXT 時，把具體卡在哪裡直接寫在回覆裡。

之後如果審查發現問題，協調者會把意見傳給你。修正後另外 commit，重跑涵蓋修改處的測試，把修正報告（改了什麼、跑了哪些指令、輸出）接在同一個報告檔後面，再用同樣的短格式回覆。
