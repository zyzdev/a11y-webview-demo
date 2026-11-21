// App 的全域設定（設計文件 §5、§5.1）：網頁來源、App 主題、Android 顯示模式。存在 SharedPreferences，
// key 就是屬性名稱。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 網頁從哪裡來：App 內建的伺服器，或使用者自己架的外部伺服器。
enum WebSource { builtIn, external }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._webSource, this._externalBaseUrl, this._themeMode, this._androidHybridComposition);

  final SharedPreferences _prefs;

  static const _kWebSource = 'webSource';
  static const _kExternalBaseUrl = 'externalBaseUrl';
  static const _kThemeMode = 'themeMode';
  static const _kAndroidHybridComposition = 'androidHybridComposition';

  /// 從 [prefs] 讀出設定。沒存過或存的值不認得時用預設值：builtIn、''、ThemeMode.system、false。
  static Future<AppSettings> load(SharedPreferences prefs) async {
    return AppSettings._(
      prefs,
      _byName(WebSource.values, prefs.getString(_kWebSource)) ?? WebSource.builtIn,
      prefs.getString(_kExternalBaseUrl) ?? '',
      _byName(ThemeMode.values, prefs.getString(_kThemeMode)) ?? ThemeMode.system,
      prefs.getBool(_kAndroidHybridComposition) ?? false,
    );
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  WebSource _webSource;
  String _externalBaseUrl;
  ThemeMode _themeMode;
  bool _androidHybridComposition;

  WebSource get webSource => _webSource;

  /// 使用者輸入的外部網址（原字串）。實際使用前要經過 [parseExternalBase]。
  String get externalBaseUrl => _externalBaseUrl;

  ThemeMode get themeMode => _themeMode;

  /// Android 的 WebView 顯示模式：true 是 Hybrid Composition，false 是預設的 TLHC。全域設定，每一頁都套用。
  bool get androidHybridComposition => _androidHybridComposition;

  Future<void> setWebSource(WebSource v) async {
    _webSource = v;
    notifyListeners();
    await _prefs.setString(_kWebSource, v.name);
  }

  Future<void> setExternalBaseUrl(String v) async {
    _externalBaseUrl = v;
    notifyListeners();
    await _prefs.setString(_kExternalBaseUrl, v);
  }

  Future<void> setThemeMode(ThemeMode v) async {
    _themeMode = v;
    notifyListeners();
    await _prefs.setString(_kThemeMode, v.name);
  }

  Future<void> setAndroidHybridComposition(bool v) async {
    _androidHybridComposition = v;
    notifyListeners();
    await _prefs.setBool(_kAndroidHybridComposition, v);
  }

  /// 把使用者輸入的外部網址轉成網頁的 base，不合法時回傳 null。
  ///
  /// 去掉頭尾空白；不含 `://` 就補上 `http://`（所以 `localhost:8000` 不會被當成 scheme 是 localhost）；
  /// scheme 必須是 http 或 https 且有 host；路徑結尾補 `/`（`buildDemoUri` 用 `base.resolve`，
  /// 少了結尾斜線會丟掉最後一段路徑）。帶查詢字串或 `#` 片段的也視為不合法，因為載入時查詢字串會被整個換掉。
  static Uri? parseExternalBase(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (uri.hasQuery || uri.hasFragment) return null;
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }
}
