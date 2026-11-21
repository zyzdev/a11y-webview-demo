import 'dart:io';

import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:flutter_test/flutter_test.dart';

/// 列出 [root] 底下所有檔案的相對路徑（用 '/' 分隔、排序過）。忽略 macOS 的 .DS_Store。
List<String> _relativeFiles(Directory root) {
  final rootPath = root.absolute.path;
  return root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((f) => f.absolute.path.substring(rootPath.length + 1).replaceAll(Platform.pathSeparator, '/'))
      .where((p) => p.split('/').last != '.DS_Store')
      .toList()
    ..sort();
}

void main() {
  // flutter test 的工作目錄是 flutter_app/。
  final webDir = Directory('../web');
  final assetsDir = Directory('assets/web');

  test('../web 和 assets/web 的檔案清單相同，每個檔案內容位元組相同（請執行 tool/sync_web.sh）', () {
    expect(webDir.existsSync(), isTrue, reason: '找不到 ../web');
    expect(assetsDir.existsSync(), isTrue, reason: '找不到 assets/web，請執行 tool/sync_web.sh');
    final webFiles = _relativeFiles(webDir);
    final assetFiles = _relativeFiles(assetsDir);
    expect(webFiles, contains('index.html'));
    expect(assetFiles, webFiles);
    for (final path in webFiles) {
      final expected = File('${webDir.path}/$path').readAsBytesSync();
      final actual = File('${assetsDir.path}/$path').readAsBytesSync();
      expect(actual, expected, reason: '$path 內容不同，請執行 tool/sync_web.sh');
    }
  });

  test('rootBundleLoader 讀得到 assets/web 的每個檔案（pubspec 有列出每個目錄），找不到時回傳 null', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = rootBundleLoader();
    final assetFiles = _relativeFiles(assetsDir);
    expect(assetFiles, isNotEmpty);
    for (final path in assetFiles) {
      final bytes = await loader(path);
      expect(bytes, isNotNull, reason: '$path 沒有被打包，檢查 pubspec.yaml 的 assets');
      expect(bytes, File('${assetsDir.path}/$path').readAsBytesSync(), reason: path);
    }
    expect(await loader('pages/missing.html'), isNull);
  });
}
