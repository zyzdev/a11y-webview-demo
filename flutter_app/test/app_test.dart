import 'package:a11y_webview_demo/app.dart';
import 'package:a11y_webview_demo/pages/home_page.dart';
import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:a11y_webview_demo/settings/settings_page.dart';
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

  testWidgets('A11yDemoApp：回到前景時 ensureRunning，說明消失，webBase 換成伺服器的網址', (tester) async {
    final settings = await AppSettings.load(await SharedPreferences.getInstance());
    final server = LocalWebServer(loader: (_) async => null);
    await tester.pumpWidget(A11yDemoApp(settings: settings, server: server, startupError: 'SocketException: boom'));
    expect(find.textContaining('內建伺服器無法啟動'), findsOneWidget);
    expect(AppScope.of(tester.element(find.byType(HomePage))).webBase.toString(), 'http://127.0.0.1/');

    // ensureRunning 是真的 socket IO，要在 runAsync 裡觸發並等它完成。
    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 200 && server.baseUri == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    try {
      expect(server.baseUri, isNotNull);
      expect(find.textContaining('內建伺服器無法啟動'), findsNothing);
      final webBase = AppScope.of(tester.element(find.byType(HomePage))).webBase;
      expect(webBase, server.baseUri);
      expect(webBase.path, endsWith('/'));
    } finally {
      await tester.runAsync(server.stop);
    }
  });

  group('伺服器錯誤說明在大字級時最多佔約三分之一，首頁仍可操作', () {
    const message = 'SocketException: Failed to create server socket (OS Error: Operation not permitted, errno = 1), '
        'address = 127.0.0.1, port = 0';
    const cases = [
      (Size(390, 844), 3.0),
      (Size(320, 568), 2.0),
    ];
    for (final (size, scale) in cases) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}、字級 $scale', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final settings = await AppSettings.load(await SharedPreferences.getInstance());
        await tester.pumpWidget(A11yDemoApp(
          settings: settings,
          server: LocalWebServer(loader: (_) async => null),
          startupError: message,
        ));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('內建伺服器無法啟動'), findsOneWidget);

        final homeHeight = tester.getSize(find.byType(HomePage)).height;
        expect(homeHeight, greaterThanOrEqualTo(size.height * 2 / 3 - 1), reason: '首頁高度 $homeHeight');

        expect(find.byTooltip('設定'), findsOneWidget);
        await tester.tap(find.byTooltip('設定'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
