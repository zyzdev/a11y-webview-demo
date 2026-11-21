// 首頁（設計文件 §5.4）：依 C／A／B／T 分區列出所有示範頁，每列顯示代號、標題、修正方、可信度、平台。

import 'package:flutter/material.dart';

import '../catalog/demo_catalog.dart';
import '../catalog/demo_spec.dart';
import '../settings/settings_page.dart';

class HomePage extends StatelessWidget {
  /// [specs] 預設 [demoCatalog]；[pageBuilder] 預設開示範頁。兩者都是為了測試可注入。
  const HomePage({super.key, this.specs, this.pageBuilder});

  final List<DemoSpec>? specs;
  final Widget Function(DemoSpec spec)? pageBuilder;

  @override
  Widget build(BuildContext context) {
    final all = specs ?? demoCatalog;
    final builder = pageBuilder ?? (spec) => _PendingDemoPage(spec: spec);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebView 無障礙範例'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final category in DemoCategory.values)
            if (all.any((s) => s.category == category)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                // 分區標題帶 header 語意，預期報讀器使用者可以用標題導覽在分區之間跳（需實機確認）。
                child: Semantics(
                  header: true,
                  child: Text(category.label, style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              for (final spec in all.where((s) => s.category == category))
                ListTile(
                  leading: Text(spec.code, style: Theme.of(context).textTheme.titleSmall),
                  title: Text(spec.title),
                  subtitle: Text(spec.badgeLine),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => builder(spec))),
                ),
            ],
        ],
      ),
    );
  }
}

/// 暫時的示範頁。Task 5 會把 [HomePage] 的預設換成 DemoPage 並刪掉它。
class _PendingDemoPage extends StatelessWidget {
  const _PendingDemoPage({required this.spec});

  final DemoSpec spec;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(spec.title)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('這一頁在後續任務實作。'),
      ),
    );
  }
}
