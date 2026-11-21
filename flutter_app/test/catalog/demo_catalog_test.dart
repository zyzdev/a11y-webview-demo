// demoCatalog 的結構檢查。測試從 flutter_app/ 執行，網頁檔讀 assets/web/ 底下的複本。
//
// 目錄目前是空的，所以另外用兩組假資料證明檢查本身抓得到錯誤（catalogProblems 對正確的資料回報空清單，
// 對故意寫錯的資料回報每一種錯）。

import 'dart:io';

import 'package:a11y_webview_demo/catalog/demo_catalog.dart';
import 'package:a11y_webview_demo/catalog/demo_spec.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:flutter_test/flutter_test.dart';

final _idPattern = RegExp(r'^[cabt]\d{2}$');
final _dataFixesPattern = RegExp(r'data-fixes="([^"]*)"');

const _categoryByPrefix = {
  'c': DemoCategory.contract,
  'a': DemoCategory.appOnly,
  'b': DemoCategory.boundary,
  't': DemoCategory.tool,
};

/// 回傳每一筆不符合結構規則的說明；全部符合時回傳空清單。
List<String> catalogProblems(List<DemoSpec> specs) {
  final problems = <String>[];
  final seenIds = <String>{};
  for (final spec in specs) {
    final id = spec.id;
    if (!seenIds.add(id)) problems.add('$id：id 重複');
    if (!_idPattern.hasMatch(id)) {
      problems.add('$id：id 格式不對');
    } else if (_categoryByPrefix[id[0]] != spec.category) {
      problems.add('$id：category 和 id 開頭不一致');
    }

    final file = File('assets/web/${spec.webPath}');
    Set<String>? declaredFixes;
    if (!file.existsSync()) {
      problems.add('$id：找不到 ${file.path}');
    } else {
      final match = _dataFixesPattern.firstMatch(file.readAsStringSync());
      if (match == null) {
        problems.add('$id：網頁檔沒有 data-fixes');
      } else {
        declaredFixes = match.group(1)!.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
      }
    }

    if (spec.variants.isEmpty) problems.add('$id：variants 是空的');
    final seenVariants = <String>{};
    for (final v in spec.variants) {
      if (!seenVariants.add(v.id)) problems.add('$id：variant id ${v.id} 重複');
      if (v.webMode != 'problem' && v.webMode != 'fixed') problems.add('$id/${v.id}：webMode 不是 problem 或 fixed');
      for (final name in v.webOff) {
        if (declaredFixes != null && !declaredFixes.contains(name)) {
          problems.add('$id/${v.id}：webOff 的 $name 不在 data-fixes 裡');
        }
      }
    }

    final h = spec.howToTest;
    if (h.steps.isEmpty) problems.add('$id：howToTest.steps 是空的');
    if (h.setup.trim().isEmpty) problems.add('$id：howToTest.setup 是空的');
    if (h.expectProblem.trim().isEmpty) problems.add('$id：howToTest.expectProblem 是空的');
    if (h.expectFixed.trim().isEmpty) problems.add('$id：howToTest.expectFixed 是空的');
    if (spec.confidence == Confidence.observation && h.evidence.isEmpty) {
      problems.add('$id：觀察頁的 evidence 是空的');
    }
  }
  return problems;
}

DemoWebViewConfig _baseline(String variantId, Map<String, String> options) => DemoWebViewConfig.baseline;

const _goodHowTo = HowToTest(setup: '前置', steps: ['步驟'], expectProblem: '問題', expectFixed: '修正', evidence: ['依據']);

void main() {
  test('demoCatalog 符合結構規則', () {
    expect(catalogProblems(demoCatalog), isEmpty);
  });

  test('檢查本身：正確的假資料沒有問題', () {
    const good = [
      DemoSpec(
        id: 'b02',
        title: '假頁',
        category: DemoCategory.boundary,
        fixSide: FixSide.none,
        confidence: Confidence.observation,
        webPath: 'pages/b-content.html',
        howToTest: _goodHowTo,
        configFor: _baseline,
      ),
      DemoSpec(
        id: 't01',
        title: '假頁二',
        category: DemoCategory.tool,
        fixSide: FixSide.none,
        confidence: Confidence.verified,
        webPath: 'pages/b-content.html',
        howToTest: _goodHowTo,
        configFor: _baseline,
        variants: [DemoVariant('only', '唯一')],
      ),
    ];
    expect(catalogProblems(good), isEmpty);
  });

  test('檢查本身：故意寫錯的假資料，每一種錯都抓得到', () {
    const bad = [
      DemoSpec(
        id: 'c01',
        title: '類別錯、webOff 不在 data-fixes、webMode 錯、variant 重複',
        category: DemoCategory.boundary,
        fixSide: FixSide.both,
        confidence: Confidence.verified,
        webPath: 'pages/b-content.html',
        howToTest: _goodHowTo,
        configFor: _baseline,
        variants: [
          DemoVariant('x', 'X', webOff: ['textScale']),
          DemoVariant('x', 'X2', webMode: 'weird'),
        ],
      ),
      DemoSpec(
        id: 'c01',
        title: 'id 重複、檔案不存在、怎麼測空白、觀察頁沒依據',
        category: DemoCategory.contract,
        fixSide: FixSide.both,
        confidence: Confidence.observation,
        webPath: 'pages/missing.html',
        howToTest: HowToTest(setup: ' ', steps: [], expectProblem: '', expectFixed: ''),
        configFor: _baseline,
      ),
      DemoSpec(
        id: 'X1',
        title: 'id 格式錯、沒有變體',
        category: DemoCategory.tool,
        fixSide: FixSide.none,
        confidence: Confidence.verified,
        webPath: 'pages/b-content.html',
        howToTest: _goodHowTo,
        configFor: _baseline,
        variants: [],
      ),
    ];
    final problems = catalogProblems(bad);
    expect(problems, contains('c01：category 和 id 開頭不一致'));
    expect(problems, contains('c01/x：webOff 的 textScale 不在 data-fixes 裡'));
    expect(problems, contains('c01/x：webMode 不是 problem 或 fixed'));
    expect(problems, contains('c01：variant id x 重複'));
    expect(problems, contains('c01：id 重複'));
    expect(problems, contains('c01：找不到 assets/web/pages/missing.html'));
    expect(problems, contains('c01：howToTest.steps 是空的'));
    expect(problems, contains('c01：howToTest.setup 是空的'));
    expect(problems, contains('c01：howToTest.expectProblem 是空的'));
    expect(problems, contains('c01：howToTest.expectFixed 是空的'));
    expect(problems, contains('c01：觀察頁的 evidence 是空的'));
    expect(problems, contains('X1：id 格式不對'));
    expect(problems, contains('X1：variants 是空的'));
  });
}
