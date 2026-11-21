import 'package:a11y_webview_demo/app.dart';
import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:a11y_webview_demo/settings/app_settings.dart';
import 'package:a11y_webview_demo/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> _pumpSettingsPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await AppSettings.load(await SharedPreferences.getInstance());
  await tester.pumpWidget(AppScope(
    settings: settings,
    server: LocalWebServer(loader: (_) async => null),
    builtInBase: Uri.parse('http://127.0.0.1:1234/'),
    child: const MaterialApp(home: SettingsPage()),
  ));
  return settings;
}

void main() {
  testWidgets('Android 時看得到顯示模式設定', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Android 顯示模式'), findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(settings.androidHybridComposition, true);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS 時看不到顯示模式設定', (tester) async {
    await _pumpSettingsPage(tester);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Android 顯示模式'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('外部網址不合法時顯示錯誤文字，設定不變', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), 'ftp://x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('不是有效的網址'), findsOneWidget);
    expect(settings.externalBaseUrl, '');
  });

  testWidgets('外部網址合法時存成正規化的網址，不顯示錯誤', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), 'ftp://x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '10.0.2.2:8000/web');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('不是有效的網址'), findsNothing);
    expect(settings.externalBaseUrl, 'http://10.0.2.2:8000/web/');
  });

  testWidgets('選網頁來源與 App 主題會寫進設定', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.tap(find.text('外部（自己架的網頁伺服器）'));
    await tester.pump();
    expect(settings.webSource, WebSource.external);
    await tester.scrollUntilVisible(find.text('深色'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('深色'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.dark);
  });
}
