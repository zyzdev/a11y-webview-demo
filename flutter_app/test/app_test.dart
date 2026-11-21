import 'package:a11y_webview_demo/app.dart';
import 'package:a11y_webview_demo/pages/home_page.dart';
import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('resolveWebBase：結果一律以 / 結尾（buildDemoUri 用 base.resolve，少了結尾斜線會丟掉最後一段路徑）', () {
    final builtIn = Uri.parse('http://127.0.0.1:5000/');

    test('內建 → 內建伺服器的網址', () {
      final base = resolveWebBase(source: WebSource.builtIn, externalBaseUrl: 'http://10.0.2.2:8000/', builtInBase: builtIn);
      expect(base, builtIn);
      expect(base.path, endsWith('/'));
    });

    test('外部（輸入不帶結尾斜線）→ 正規化後的外部網址', () {
      final base =
          resolveWebBase(source: WebSource.external, externalBaseUrl: 'http://10.0.2.2:8000/web', builtInBase: builtIn);
      expect(base.toString(), 'http://10.0.2.2:8000/web/');
      expect(base.path, endsWith('/'));
    });

    test('外部但網址不合法或空白 → 退回內建', () {
      for (final input in ['ftp://x', '', '   ']) {
        final base = resolveWebBase(source: WebSource.external, externalBaseUrl: input, builtInBase: builtIn);
        expect(base, builtIn, reason: input);
        expect(base.path, endsWith('/'));
      }
    });

    test('真的啟動的內建伺服器，baseUri 以 / 結尾，resolveWebBase 原樣使用', () async {
      final server = LocalWebServer(loader: (_) async => null);
      try {
        final uri = await server.start();
        expect(uri.path, endsWith('/'));
        final base = resolveWebBase(source: WebSource.builtIn, externalBaseUrl: '', builtInBase: uri);
        expect(base, uri);
      } finally {
        await server.stop();
      }
    });
  });

  testWidgets('AppScope.of 取得 settings、server、webBase；設定改變時依賴者重建', (tester) async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    final server = LocalWebServer(loader: (_) async => null);
    final seen = <Uri>[];
    await tester.pumpWidget(AppScope(
      settings: settings,
      server: server,
      builtInBase: Uri.parse('http://127.0.0.1:5000/'),
      child: Builder(builder: (context) {
        final scope = AppScope.of(context);
        expect(scope.settings, same(settings));
        expect(scope.server, same(server));
        seen.add(scope.webBase);
        return const SizedBox();
      }),
    ));
    expect(seen.last.toString(), 'http://127.0.0.1:5000/');

    await settings.setExternalBaseUrl('http://10.0.2.2:8000/web');
    await settings.setWebSource(WebSource.external);
    await tester.pump();
    expect(seen.last.toString(), 'http://10.0.2.2:8000/web/');
  });

  testWidgets('A11yDemoApp：顯示首頁；App 主題跟著設定改變', (tester) async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    await tester.pumpWidget(A11yDemoApp(settings: settings, server: LocalWebServer(loader: (_) async => null)));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.textContaining('內建伺服器無法啟動'), findsNothing);

    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.dark);
    await settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(HomePage))).brightness, Brightness.light);
  });

  testWidgets('A11yDemoApp：內建伺服器啟動失敗時仍顯示首頁，並在上方說明', (tester) async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    await tester.pumpWidget(A11yDemoApp(
      settings: settings,
      server: LocalWebServer(loader: (_) async => null),
      startupError: 'SocketException: boom',
    ));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.textContaining('內建伺服器無法啟動'), findsOneWidget);
    expect(find.textContaining('SocketException: boom'), findsOneWidget);
  });
}
