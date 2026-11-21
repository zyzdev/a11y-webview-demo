// App → 網頁的約定（設計文件 §6.1、§6.2）。純 Dart，不依賴 Flutter，可以直接單元測試。
// 網頁端的對應實作是 web/shared/a11y-app.js（parseParams、buildSearch、normalizeSettings）。

import 'dart:convert';

/// App 要告訴網頁的設定。null 表示不傳這一項（網頁就照自己的預設或偵測值）。
class WebSettingsSnapshot {
  const WebSettingsSnapshot({this.lang, this.theme, this.textScale, this.bold, this.contrast, this.reduceMotion});

  /// BCP 47 語系，例如 `zh-TW`。
  final String? lang;

  /// `light` 或 `dark`：App 實際顯示的主題。
  final String? theme;

  /// 字級倍率。有帶代表「由網頁負責放大」；值應先經過 [normalizeTextScale]。
  final double? textScale;

  final bool? bold;
  final bool? contrast;
  final bool? reduceMotion;

  @override
  bool operator ==(Object other) =>
      other is WebSettingsSnapshot &&
      other.lang == lang &&
      other.theme == theme &&
      other.textScale == textScale &&
      other.bold == bold &&
      other.contrast == contrast &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(lang, theme, textScale, bold, contrast, reduceMotion);
}

const double _minTextScale = 0.8;
const double _maxTextScale = 3.0;

/// 把 App 的字級倍率限制在 0.8–3.0，並四捨五入到兩位小數（設計文件 §6.1）。
double normalizeTextScale(double raw) {
  final clamped = raw.clamp(_minTextScale, _maxTextScale).toDouble();
  return (clamped * 100).round() / 100;
}

/// 組出要載入的網址。
///
/// [webPath] 是相對於 [base] 的路徑（例如 `pages/b-content.html`），[base] 的路徑前綴會保留。
/// 查詢字串自己組，順序固定為 `mode, off, embedded, lang, theme, textScale, bold, contrast,
/// reduceMotion`，最後接 [extraQuery]。值為 null 的設定不輸出。
Uri buildDemoUri({
  required Uri base,
  required String webPath,
  required String webMode,
  List<String> webOff = const [],
  required bool embedded,
  WebSettingsSnapshot settings = const WebSettingsSnapshot(),
  Map<String, String> extraQuery = const {},
}) {
  final parts = <String>[];
  void add(String name, String value) => parts.add('$name=${Uri.encodeQueryComponent(value)}');
  String flag(bool value) => value ? '1' : '0';

  add('mode', webMode);
  if (webOff.isNotEmpty) add('off', webOff.join(','));
  if (embedded) add('embedded', '1');
  final s = settings;
  if (s.lang != null) add('lang', s.lang!);
  if (s.theme != null) add('theme', s.theme!);
  if (s.textScale != null) add('textScale', s.textScale!.toStringAsFixed(2));
  if (s.bold != null) add('bold', flag(s.bold!));
  if (s.contrast != null) add('contrast', flag(s.contrast!));
  if (s.reduceMotion != null) add('reduceMotion', flag(s.reduceMotion!));
  extraQuery.forEach(add);

  return base.resolve(webPath).replace(query: parts.join('&'));
}

/// 組出呼叫 `window.a11yApp.<method>(...)` 的腳本。
///
/// 網頁腳本可能還沒載入，所以先檢查 `window.a11yApp` 存在（設計文件 §6.2）。
/// 引數用 [jsonEncode] 轉成 JS 字面值，以逗號相接、不加空白。
String jsCall(String method, [List<Object?> args = const []]) {
  final encoded = args.map(jsonEncode).join(',');
  return 'window.a11yApp&&window.a11yApp.$method($encoded);';
}

/// `updateSettings` 的呼叫腳本，只帶非 null 的欄位。
///
/// 值用 JSON 原生型別（數字、布林），網頁端的 normalizeSettings 以 typeof 驗證。
String updateSettingsScript(WebSettingsSnapshot s) {
  final settings = <String, Object>{
    if (s.lang != null) 'lang': s.lang!,
    if (s.theme != null) 'theme': s.theme!,
    if (s.textScale != null) 'textScale': s.textScale!,
    if (s.bold != null) 'bold': s.bold!,
    if (s.contrast != null) 'contrast': s.contrast!,
    if (s.reduceMotion != null) 'reduceMotion': s.reduceMotion!,
  };
  return jsCall('updateSettings', [settings]);
}

/// 目前頂層網址是否屬於自家網頁（設計文件 §6.3 的信任範圍）。
///
/// scheme、host、port 都要相同，而且路徑在 [webBase] 的路徑之下。路徑以「/」為界比對，
/// 所以 `/web/` 不會放行 `/webevil/`。
bool isTrustedPage(Uri? current, Uri webBase) {
  if (current == null) return false;
  if (current.scheme != webBase.scheme || current.host != webBase.host || current.port != webBase.port) {
    return false;
  }
  final basePath = webBase.normalizePath().path;
  final path = current.normalizePath().path;
  final prefix = basePath.endsWith('/') ? basePath : '$basePath/';
  return path == basePath || path.startsWith(prefix);
}
