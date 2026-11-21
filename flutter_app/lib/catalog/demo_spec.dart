// 每個示範頁的宣告（設計文件 §4 的類別、修正方、可信度、平台；§5.3 的變體）。

import 'package:flutter/widgets.dart';

import '../webview/demo_web_controller.dart';
import '../webview/demo_webview_config.dart';

/// 類別，對應代號開頭 c、a、b、t。
enum DemoCategory {
  contract('兩邊約定'),
  appOnly('App 單方處理'),
  boundary('交界處限制'),
  tool('工具');

  const DemoCategory(this.label);

  /// 首頁分區的名稱。
  final String label;
}

/// 誰能修（設計文件 §4）。
enum FixSide {
  app('App'),
  web('網頁'),
  both('兩邊'),
  either('App 或網頁擇一'),
  none(null);

  const FixSide(this.label);

  /// 顯示用的文字；[none] 為 null，表示不顯示修正方。
  final String? label;
}

/// 可信度（設計文件 §2）。
enum Confidence {
  verified('已查證'),
  needsDeviceTest('需實機確認'),
  observation('觀察頁');

  const Confidence(this.label);
  final String label;
}

/// 這一頁適用的平台。
enum DemoPlatform {
  both('兩個平台'),
  android('只有 Android'),
  ios('只有 iOS');

  const DemoPlatform(this.label);
  final String label;
}

/// 一個變體。[webMode] 和 [webOff] 對應 URL 參數 `mode`、`off`（設計文件 §6.1）。
class DemoVariant {
  const DemoVariant(this.id, this.label, {this.webMode = 'fixed', this.webOff = const []});
  final String id, label, webMode;
  final List<String> webOff;
}

/// 頁面上的一個下拉選項，例如「按鈕位置」。[choices] 的第一個是預設值。
class DemoOption {
  const DemoOption(this.id, this.label, this.choices);
  final String id, label;
  final List<String> choices;
}

/// 「怎麼測」：前置、步驟、兩段預期、依據、看哪些檔案。
class HowToTest {
  const HowToTest({
    required this.setup,
    required this.steps,
    required this.expectProblem,
    required this.expectFixed,
    this.evidence = const [],
    this.codeRefs = const [],
  });

  final String setup;
  final List<String> steps;
  final String expectProblem;
  final String expectFixed;
  final List<String> evidence;
  final List<String> codeRefs;
}

typedef DemoBodyBuilder = Widget Function(BuildContext context, DemoVariant variant, Widget webView, DemoWebController web);
typedef DemoToolbarBuilder = List<Widget> Function(BuildContext context, DemoWebController web);

class DemoSpec {
  const DemoSpec({
    required this.id,
    required this.title,
    required this.category,
    required this.fixSide,
    required this.confidence,
    required this.webPath,
    required this.howToTest,
    required this.configFor,
    this.platform = DemoPlatform.both,
    this.variants = kProblemFixed,
    this.options = const [],
    this.bodyBuilder,
    this.toolbarBuilder,
  });

  /// 小寫代號，例如 `c01`。
  final String id;
  final String title;
  final DemoCategory category;
  final FixSide fixSide;
  final Confidence confidence;

  /// 相對於網頁 base 的路徑，例如 `pages/c01-text-scale.html`。
  final String webPath;
  final HowToTest howToTest;

  /// 依變體與選項決定 DemoWebView 的設定。
  final DemoWebViewConfig Function(String variantId, Map<String, String> options) configFor;
  final DemoPlatform platform;
  final List<DemoVariant> variants;
  final List<DemoOption> options;

  /// 需要特殊版面時提供；null 時 body 就是 WebView。
  final DemoBodyBuilder? bodyBuilder;

  /// AppBar 額外的動作按鈕。
  final DemoToolbarBuilder? toolbarBuilder;

  /// 顯示用的大寫代號，例如 `C01`。
  String get code => id.toUpperCase();

  /// 標示列的文字，例如「修正在：兩邊 · 已查證 · 兩個平台」。修正方是 [FixSide.none] 時省略第一段。
  String get badgeLine => [
        if (fixSide.label != null) '修正在：${fixSide.label}',
        confidence.label,
        platform.label,
      ].join(' · ');
}

const kProblemFixed = [DemoVariant('problem', '問題版', webMode: 'problem'), DemoVariant('fixed', '修正版')];
