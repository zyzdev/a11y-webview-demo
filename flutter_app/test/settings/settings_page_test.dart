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

  testWidgets('離開輸入框（沒按完成鍵）：檢查並存成正規化的網址，但不改寫使用者打的字', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), '10.0.2.2:8000');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(settings.externalBaseUrl, 'http://10.0.2.2:8000/');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '10.0.2.2:8000');

    await tester.enterText(find.byType(TextField), 'ftp://x');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.textContaining('不是有效的網址'), findsOneWidget);
    expect(settings.externalBaseUrl, 'http://10.0.2.2:8000/');
  });

  testWidgets('打了網址沒離開輸入框就選「外部」：先存起來，畫面立刻顯示新的位置，不改寫使用者打的字', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), '10.0.2.2:8000');
    await tester.pump();
    await tester.tap(find.text('外部（自己架的網頁伺服器）'));
    await tester.pump();
    // 點選項不會讓輸入框失焦，所以這裡的儲存不是失焦觸發的。
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, true);
    expect(settings.webSource, WebSource.external);
    expect(settings.externalBaseUrl, 'http://10.0.2.2:8000/');
    expect(find.text('目前載入網頁的位置：http://10.0.2.2:8000/'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '10.0.2.2:8000');
  });

  testWidgets('打了不合法的網址就選「外部」：顯示錯誤文字，不存，位置仍是內建', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), 'ftp://x');
    await tester.pump();
    await tester.tap(find.text('外部（自己架的網頁伺服器）'));
    await tester.pump();
    expect(find.textContaining('不是有效的網址'), findsOneWidget);
    expect(settings.externalBaseUrl, '');
    expect(find.text('目前載入網頁的位置：http://127.0.0.1:1234/'), findsOneWidget);
  });

  testWidgets('打了埠號超過 int 範圍的網址就選「外部」：不丟例外、顯示錯誤文字、不存', (tester) async {
    final settings = await _pumpSettingsPage(tester);
    await tester.enterText(find.byType(TextField), 'http://h:99999999999999999999/');
    await tester.pump();
    await tester.tap(find.text('外部（自己架的網頁伺服器）'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('不是有效的網址'), findsOneWidget);
    expect(settings.externalBaseUrl, '');
    expect(settings.webSource, WebSource.external);
  });
}
