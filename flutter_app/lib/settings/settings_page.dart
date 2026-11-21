// 設定頁：網頁來源、App 主題、Android 顯示模式（只在 Android 顯示）。

import 'package:flutter/material.dart';

import '../app.dart';
import 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _url = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  bool _urlLoaded = false;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    // 離開輸入框時也確認一次，不必一定按鍵盤的完成鍵。這時不改寫輸入框的文字：
    // 失焦不一定是使用者打完了，改寫會打斷還沒打完的網址。
    _urlFocus.addListener(() {
      if (!_urlFocus.hasFocus) _commitUrl(rewriteField: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_urlLoaded) {
      _url.text = AppScope.of(context).settings.externalBaseUrl;
      _urlLoaded = true;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  /// 在送出或離開輸入框時才檢查，不在每打一個字時檢查：打到一半的網址一定不合法，
  /// 錯誤訊息一直出現又消失，報讀器使用者可能會被反覆打斷。
  ///
  /// 合法時存成正規化後的網址；[rewriteField] 為 true（按了完成鍵）時，輸入框也改成正規化後的網址。
  void _commitUrl({required bool rewriteField}) {
    if (!mounted) return;
    final settings = AppScope.of(context).settings;
    final text = _url.text.trim();
    if (text.isEmpty) {
      setState(() => _urlError = null);
      if (settings.externalBaseUrl.isNotEmpty) settings.setExternalBaseUrl('');
      return;
    }
    final parsed = AppSettings.parseExternalBase(text);
    if (parsed == null) {
      setState(() => _urlError = '不是有效的網址。請輸入 http 或 https 開頭的網址，例如 http://10.0.2.2:8000/。設定沒有變更。');
      return;
    }
    final normalized = parsed.toString();
    setState(() {
      _urlError = null;
      if (rewriteField) _url.text = normalized;
    });
    if (settings.externalBaseUrl != normalized) settings.setExternalBaseUrl(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    // 用 Theme 的 platform 而不是 dart:io 的 Platform，元件測試才能覆寫平台。
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader('網頁來源'),
          RadioGroup<WebSource>(
            groupValue: settings.webSource,
            onChanged: (v) {
              if (v == null) return;
              // 選「外部」時輸入框可能還有焦點、內容還沒存；先存起來，「目前載入網頁的位置」才會立刻反映。
              if (v == WebSource.external) _commitUrl(rewriteField: false);
              settings.setWebSource(v);
            },
            child: const Column(
              children: [
                RadioListTile<WebSource>(value: WebSource.builtIn, title: Text('內建（App 內的伺服器）')),
                RadioListTile<WebSource>(value: WebSource.external, title: Text('外部（自己架的網頁伺服器）')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _url,
              focusNode: _urlFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onSubmitted: (_) => _commitUrl(rewriteField: true),
              decoration: InputDecoration(
                labelText: '外部網址',
                hintText: 'http://10.0.2.2:8000/',
                helperText: 'Android 模擬器連到這台電腦用 10.0.2.2。網址不合法時使用內建網頁。',
                helperMaxLines: 3,
                errorText: _urlError,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('目前載入網頁的位置：${scope.webBase}'),
          ),
          const _SectionHeader('App 主題'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (v) {
              if (v != null) settings.setThemeMode(v);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(value: ThemeMode.system, title: Text('跟隨系統')),
                RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('淺色')),
                RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('深色')),
              ],
            ),
          ),
          if (isAndroid) ...[
            const _SectionHeader('Android 顯示模式'),
            SwitchListTile(
              value: settings.androidHybridComposition,
              onChanged: settings.setAndroidHybridComposition,
              title: const Text('使用 Hybrid Composition'),
              subtitle: const Text('關閉時使用預設的 TLHC。這是全域設定，每個示範頁都會套用。'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
