// App 的根：MaterialApp（主題、語系）、AppScope（設定、內建伺服器、網頁 base）、生命週期監聽。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/home_page.dart';
import 'server/local_web_server.dart';
import 'settings/app_settings.dart';

/// 決定網頁的 base：外部來源而且網址合法時用外部網址，否則用內建伺服器的網址。
///
/// 結果一律以 `/` 結尾：`buildDemoUri` 用 `base.resolve(webPath)`，少了結尾斜線會丟掉最後一段路徑。
/// 內建伺服器的 `baseUri` 和 [AppSettings.parseExternalBase] 的結果都已經以 `/` 結尾。
Uri resolveWebBase({required WebSource source, required String externalBaseUrl, required Uri builtInBase}) {
  if (source == WebSource.external) {
    final external = AppSettings.parseExternalBase(externalBaseUrl);
    if (external != null) return external;
  }
  return builtInBase;
}

/// 讓下層取得設定、內建伺服器與網頁 base。設定改變時依賴它的元件會重建。
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required this.server,
    required this.builtInBase,
    required super.child,
  }) : super(notifier: settings);

  final LocalWebServer server;

  /// 內建伺服器最近一次成功啟動的網址（以 `/` 結尾）。從沒啟動成功時是一個連不上的替代網址，
  /// 示範頁會載入失敗並顯示錯誤，而不是讓 App 當掉。
  final Uri builtInBase;

  AppSettings get settings => notifier!;

  /// 目前要載入網頁的 base，一律以 `/` 結尾。
  Uri get webBase {
    final base = resolveWebBase(
      source: settings.webSource,
      externalBaseUrl: settings.externalBaseUrl,
      builtInBase: builtInBase,
    );
    assert(base.path.endsWith('/'), 'webBase 必須以 / 結尾：$base');
    return base;
  }

  static AppScope of(BuildContext c) {
    final scope = c.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, '找不到 AppScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.notifier != notifier || oldWidget.server != server || oldWidget.builtInBase != builtInBase;
}

class A11yDemoApp extends StatefulWidget {
  const A11yDemoApp({super.key, required this.settings, required this.server, this.startupError});

  final AppSettings settings;
  final LocalWebServer server;

  /// 內建伺服器啟動失敗的原因。不是 null 時畫面上方顯示說明。
  final String? startupError;

  @override
  State<A11yDemoApp> createState() => _A11yDemoAppState();
}

class _A11yDemoAppState extends State<A11yDemoApp> with WidgetsBindingObserver {
  /// 內建伺服器從沒啟動成功時用的替代網址：連不上，示範頁會顯示載入失敗。
  static final Uri _unavailableBase = Uri.parse('http://127.0.0.1/');

  late Uri _builtInBase;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _builtInBase = widget.server.baseUri ?? _unavailableBase;
    _serverError = widget.startupError;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS 會在 App 暫停時回收 socket（設計文件 §5.1），回到前景時確認伺服器還活著。
    if (state == AppLifecycleState.resumed) _ensureServer();
  }

  Future<void> _ensureServer() async {
    try {
      final uri = await widget.server.ensureRunning();
      if (!mounted) return;
      if (uri != _builtInBase || _serverError != null) {
        setState(() {
          _builtInBase = uri;
          _serverError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      server: widget.server,
      builtInBase: _builtInBase,
      child: Builder(builder: (context) {
        final settings = AppScope.of(context).settings;
        final error = _serverError;
        return MaterialApp(
          title: 'WebView 無障礙範例',
          themeMode: settings.themeMode,
          theme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
          darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
          builder: error == null ? null : (context, child) => _ServerErrorNotice(message: error, child: child!),
          home: const HomePage(),
        );
      }),
    );
  }
}

/// 內建伺服器無法啟動時，在每一頁的最上方顯示一行說明。
class _ServerErrorNotice extends StatelessWidget {
  const _ServerErrorNotice({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          // 說明最多佔約三分之一高度（至少留得下狀態列加一行字），超過時在這一塊裡捲動。
          // 大字級時說明才不會蓋掉下面的頁面，使用者仍點得到「設定」。
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(constraints.maxHeight / 3, topPadding + 48)),
            child: Material(
              color: scheme.errorContainer,
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '內建伺服器無法啟動，示範頁載不到內建網頁。可以到設定改用外部網頁來源，或重新開啟 App。（$message）',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
          ),
        ],
      ),
    );
  }
}
