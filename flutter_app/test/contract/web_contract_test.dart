import 'package:a11y_webview_demo/contract/web_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDemoUri', () {
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

    test('query values are encoded with encodeQueryComponent', () {
      final uri = buildDemoUri(base: Uri.parse('http://127.0.0.1:8123/'), webPath: 'pages/a.html', webMode: 'fixed',
          embedded: false, extraQuery: const {'q': 'a b&c=d'});
      expect(uri.toString(), 'http://127.0.0.1:8123/pages/a.html?mode=fixed&q=a+b%26c%3Dd');
      expect(uri.queryParameters['q'], 'a b&c=d');
    });
  });

  test('normalizeTextScale', () {
    expect(normalizeTextScale(0.5), 0.8); expect(normalizeTextScale(3.12), 3.0); expect(normalizeTextScale(1.2999), 1.3);
  });

  test('jsCall', () {
    expect(jsCall('handleBack'), 'window.a11yApp&&window.a11yApp.handleBack();');
    expect(jsCall('onNativeDialogClosed', ['r1', '刪除']), 'window.a11yApp&&window.a11yApp.onNativeDialogClosed("r1","刪除");');
  });

  test('jsCall escapes string arguments as JSON', () {
    expect(jsCall('f', ['a"b\\c\n', null, 2, true]), 'window.a11yApp&&window.a11yApp.f("a\\"b\\\\c\\n",null,2,true);');
  });

  test('updateSettingsScript', () {
    expect(updateSettingsScript(const WebSettingsSnapshot(theme: 'dark', textScale: 1.3)),
        'window.a11yApp&&window.a11yApp.updateSettings({"theme":"dark","textScale":1.3});');
  });

  test('updateSettingsScript keeps field order and sends JSON booleans', () {
    expect(
        updateSettingsScript(const WebSettingsSnapshot(
            reduceMotion: false, contrast: true, bold: false, textScale: 2.0, theme: 'light', lang: 'en')),
        'window.a11yApp&&window.a11yApp.updateSettings('
        '{"lang":"en","theme":"light","textScale":2.0,"bold":false,"contrast":true,"reduceMotion":false});');
    expect(updateSettingsScript(const WebSettingsSnapshot()), 'window.a11yApp&&window.a11yApp.updateSettings({});');
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

  test('isTrustedPage compares path segments, scheme and host', () {
    final sub = Uri.parse('http://10.0.2.2:8000/web/');
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/webevil/a.html'), sub), false);
    expect(isTrustedPage(Uri.parse('https://10.0.2.2:8000/web/a.html'), sub), false);
    expect(isTrustedPage(Uri.parse('http://10.0.2.3:8000/web/a.html'), sub), false);
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/web/../other/a.html'), sub), false);
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/web/%2e%2e/other/a.html'), sub), false);

    // webBase 沒有結尾斜線：/web 本身和底下的路徑可以，/webevil 不行。
    final noSlash = Uri.parse('http://10.0.2.2:8000/web');
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/web'), noSlash), true);
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/web/pages/a.html'), noSlash), true);
    expect(isTrustedPage(Uri.parse('http://10.0.2.2:8000/webevil/a.html'), noSlash), false);

    // webBase 路徑是空的：整個 origin 都算。
    final empty = Uri.parse('http://127.0.0.1:8123');
    expect(isTrustedPage(Uri.parse('http://127.0.0.1:8123'), empty), true);
    expect(isTrustedPage(Uri.parse('http://127.0.0.1:8123/pages/a.html'), empty), true);
    expect(isTrustedPage(Uri.parse('http://127.0.0.1:8124/pages/a.html'), empty), false);
  });

  test('WebSettingsSnapshot has value equality', () {
    // 用執行期才知道的值建第二個物件，避免 const 正規化成同一個實例而讓比較失去意義。
    final runtimeLang = ['zh', 'TW'].join('-');
    const a = WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3, bold: true, contrast: false, reduceMotion: true);
    final b = WebSettingsSnapshot(lang: runtimeLang, theme: 'dark', textScale: 1.3, bold: true, contrast: false, reduceMotion: true);
    expect(identical(a, b), false);
    expect(a == b, true);
    expect(a.hashCode, b.hashCode);
    expect(a == const WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.3, bold: true, contrast: false), false);
    expect(const WebSettingsSnapshot(textScale: 1.3) == const WebSettingsSnapshot(textScale: 1.31), false);
  });
}
