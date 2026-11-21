import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parseExternalBase', () {
    expect(AppSettings.parseExternalBase(''), isNull);
    expect(AppSettings.parseExternalBase('   '), isNull);
    expect(AppSettings.parseExternalBase('ftp://x'), isNull);
    expect(AppSettings.parseExternalBase('192.168.1.10:8000').toString(), 'http://192.168.1.10:8000/');
    expect(AppSettings.parseExternalBase('localhost:8000').toString(), 'http://localhost:8000/'); // 不能被當成 scheme 是 localhost
    expect(AppSettings.parseExternalBase('http://10.0.2.2:8000/web').toString(), 'http://10.0.2.2:8000/web/');
    expect(AppSettings.parseExternalBase('https://example.test/a/').toString(), 'https://example.test/a/');
  });

  test('parseExternalBase：頭尾空白去掉；沒有 host 回傳 null', () {
    expect(AppSettings.parseExternalBase('  http://10.0.2.2:8000  ').toString(), 'http://10.0.2.2:8000/');
    expect(AppSettings.parseExternalBase('http://'), isNull);
  });

  test('parseExternalBase：埠號要在 1–65535；host 含空白或 percent-encoding（例如全形字）不合法', () {
    expect(AppSettings.parseExternalBase('10.0.2.2:80000'), isNull);
    expect(AppSettings.parseExternalBase('http://h:-1/'), isNull);
    expect(AppSettings.parseExternalBase('10.0.2.2:0'), isNull);
    expect(AppSettings.parseExternalBase('10.0.2.2 :8000'), isNull);
    expect(AppSettings.parseExternalBase('ｈｔｔｐ：／／１０．０．２．２'), isNull);
    expect(AppSettings.parseExternalBase('10.0.2.2:65535').toString(), 'http://10.0.2.2:65535/');
    expect(AppSettings.parseExternalBase('10.0.2.2:1').toString(), 'http://10.0.2.2:1/');
  });

  test('parseExternalBase：埠號超過 int 範圍時回傳 null，不丟例外', () {
    expect(AppSettings.parseExternalBase('http://h:99999999999999999999/'), isNull);
    expect(AppSettings.parseExternalBase('10.0.2.2:99999999999999999999'), isNull);
  });

  test('parseExternalBase：帶查詢字串或 # 片段不合法', () {
    expect(AppSettings.parseExternalBase('http://10.0.2.2:8000/?a=1'), isNull);
    expect(AppSettings.parseExternalBase('http://10.0.2.2:8000/#top'), isNull);
  });

  test('預設值：builtIn、空字串、ThemeMode.system、false', () async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    expect(settings.webSource, WebSource.builtIn);
    expect(settings.externalBaseUrl, '');
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.androidHybridComposition, false);
  });

  test('setThemeMode(ThemeMode.dark) 後重新 load 仍是 dark', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load(prefs);
    await settings.setThemeMode(ThemeMode.dark);
    final reloaded = await AppSettings.load(prefs);
    expect(reloaded.themeMode, ThemeMode.dark);
  });

  test('每個設定都存進 SharedPreferences，key 是屬性名稱，重新 load 後相同', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AppSettings.load(prefs);
    await settings.setWebSource(WebSource.external);
    await settings.setExternalBaseUrl('http://10.0.2.2:8000/');
    await settings.setThemeMode(ThemeMode.light);
    await settings.setAndroidHybridComposition(true);
    expect(prefs.getKeys(),
        containsAll(<String>['webSource', 'externalBaseUrl', 'themeMode', 'androidHybridComposition']));
    final reloaded = await AppSettings.load(prefs);
    expect(reloaded.webSource, WebSource.external);
    expect(reloaded.externalBaseUrl, 'http://10.0.2.2:8000/');
    expect(reloaded.themeMode, ThemeMode.light);
    expect(reloaded.androidHybridComposition, true);
  });

  test('存的值不認得時用預設值', () async {
    SharedPreferences.setMockInitialValues({'webSource': 'nope', 'themeMode': 'purple'});
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    expect(settings.webSource, WebSource.builtIn);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('每個 setter 都會 notifyListeners', () async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    var count = 0;
    settings.addListener(() => count++);
    await settings.setWebSource(WebSource.external);
    expect(count, 1);
    await settings.setExternalBaseUrl('http://10.0.2.2:8000/');
    expect(count, 2);
    await settings.setThemeMode(ThemeMode.dark);
    expect(count, 3);
    await settings.setAndroidHybridComposition(true);
    expect(count, 4);
  });
}
