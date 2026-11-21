import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'server/local_web_server.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load(await SharedPreferences.getInstance());
  final server = LocalWebServer(loader: rootBundleLoader());
  String? startupError;
  try {
    await server.start();
  } catch (e) {
    // 啟動失敗仍然要顯示畫面（不能白畫面），由 A11yDemoApp 在上方說明原因。
    startupError = '$e';
    debugPrint('內建伺服器無法啟動：$e');
  }
  runApp(A11yDemoApp(settings: settings, server: server, startupError: startupError));
}
