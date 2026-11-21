// 只有特定平台才有的 WebView 設定。每個函式在不適用的平台上什麼都不做，呼叫端不必先判斷平台。
//
// 平台用 WebViewController.platform 的實際型別判斷，不用 dart:io 的 Platform：
// 判斷的是「這個 WebView 實際是哪一種」，測試換成假的實作時也不會誤呼叫原生 API。

import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 建立 WebView 的元件。
///
/// Android 依 [hybridComposition] 選顯示模式：true 是 Hybrid Composition，false 是預設的 TLHC
/// （設計文件 §4.3：兩種模式在報讀器上的表現不同，所以做成全域可切換）。顯示模式在建立時決定，
/// 要換模式就得重建 WebView。其他平台只有一種模式，[hybridComposition] 不影響。
Widget buildPlatformWebViewWidget(WebViewController c, {required bool hybridComposition}) {
  if (c.platform is AndroidWebViewController) {
    return WebViewWidget.fromPlatformCreationParams(
      params: AndroidWebViewWidgetCreationParams(
        controller: c.platform,
        displayWithHybridComposition: hybridComposition,
      ),
    );
  }
  return WebViewWidget(controller: c);
}

/// Android：設定 WebView 的文字縮放百分比（`WebSettings.setTextZoom`）。非 Android 不做事。
///
/// Android WebView 建立時會自動套用系統字級，之後不再追蹤；一旦呼叫 setTextZoom 就取代這個自動行為
/// （設計文件 §3 第 1 點、§6.1）。「網頁負責」傳 100，關掉 WebView 自己的放大，避免和網頁的根字級重複放大；
/// 「App 負責」傳倍率×100。
Future<void> applyAndroidTextZoom(WebViewController c, int percent) async {
  final platform = c.platform;
  if (platform is AndroidWebViewController) {
    await platform.setTextZoom(percent);
  }
}

/// iOS：在目前的網頁注入 `document.documentElement.style.webkitTextSizeAdjust`。非 iOS 不做事。
///
/// WKWebView 預設不跟隨 iOS 的動態字級（設計文件 §3 第 1 點），「App 負責」策略用這個方式放大網頁的字。
/// 它只作用在已經載入的這一份文件，換頁後要重新注入；iPad 上是否有效需實機確認（設計文件 §6.1）。
Future<void> applyIosTextSizeAdjust(WebViewController c, int percent) async {
  if (c.platform is WebKitWebViewController) {
    await c.runJavaScript("document.documentElement.style.webkitTextSizeAdjust='$percent%';");
  }
}
