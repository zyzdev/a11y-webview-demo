// 使用者按返回時該做什麼（設計文件 §6.2、§7 C07）。純 Dart，不依賴 Flutter。

/// 返回鍵的處理方式。
enum BackAction {
  /// 網頁回報過有東西要先關（backState），呼叫 `window.a11yApp.handleBack()` 交給網頁處理。
  askWeb,

  /// 網頁沒有要先關的東西，但 WebView 有上一頁，回到上一頁。
  webHistoryBack,

  /// 兩者都沒有，關閉整個 WebView 畫面。
  popRoute,
}

/// 依序檢查：網頁要先處理 → WebView 有上一頁 → 離開畫面。
BackAction decideBack({required bool webWantsBack, required bool webCanGoBack}) {
  if (webWantsBack) return BackAction.askWeb;
  if (webCanGoBack) return BackAction.webHistoryBack;
  return BackAction.popRoute;
}

/// 給 `PopScope.canPop` 用：只有 [decideBack] 決定離開畫面時，路由才可以直接被 pop。
bool routeCanPop({required bool webWantsBack, required bool webCanGoBack}) =>
    decideBack(webWantsBack: webWantsBack, webCanGoBack: webCanGoBack) == BackAction.popRoute;
