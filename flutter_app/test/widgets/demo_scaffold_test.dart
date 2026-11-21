import 'package:a11y_webview_demo/catalog/demo_spec.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:a11y_webview_demo/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DemoWebViewConfig _baseline(String variantId, Map<String, String> options) => DemoWebViewConfig.baseline;

const _howTo = HowToTest(
  setup: '前置：把系統字級調到最大',
  steps: ['步驟一：開啟這一頁', '步驟二：切換到修正版'],
  expectProblem: '問題版預期：字沒有變大',
  expectFixed: '修正版預期：字跟著變大',
  evidence: ['依據：WebKit bug 187013'],
  codeRefs: ['lib/webview/demo_webview.dart'],
);

DemoSpec _spec({
  FixSide fixSide = FixSide.both,
  Confidence confidence = Confidence.verified,
  DemoPlatform platform = DemoPlatform.both,
  List<DemoVariant> variants = kProblemFixed,
  List<DemoOption> options = const [],
}) =>
    DemoSpec(
      id: 'c01',
      title: '字體大小',
      category: DemoCategory.contract,
      fixSide: fixSide,
      confidence: confidence,
      webPath: 'pages/b-content.html',
      howToTest: _howTo,
      configFor: _baseline,
      platform: platform,
      variants: variants,
      options: options,
    );

Widget _app({
  required DemoSpec spec,
  DemoVariant? variant,
  ValueChanged<String>? onVariantChanged,
  String title = '網頁標題',
  bool titleIsLiveRegion = false,
  Map<String, String> options = const {},
  void Function(String optionId, String value)? onOptionChanged,
  Widget? statusLine,
}) =>
    MaterialApp(
      home: DemoScaffold(
        spec: spec,
        variant: variant ?? spec.variants.first,
        onVariantChanged: onVariantChanged ?? (_) {},
        title: title,
        titleIsLiveRegion: titleIsLiveRegion,
        body: const Text('BODY'),
        options: options,
        onOptionChanged: onOptionChanged,
        statusLine: statusLine,
      ),
    );

void main() {
  testWidgets('兩個變體 → 兩個 ChoiceChip；點「修正版」呼叫 onVariantChanged(\'fixed\')', (tester) async {
    String? changed;
    await tester.pumpWidget(_app(spec: _spec(), onVariantChanged: (id) => changed = id));
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.widgetWithText(ChoiceChip, '問題版'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '修正版'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '修正版'));
    await tester.pump();
    expect(changed, 'fixed');
  });

  testWidgets('目前的變體是選取狀態', (tester) async {
    await tester.pumpWidget(_app(spec: _spec(), variant: kProblemFixed[1]));
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips[0].selected, false);
    expect(chips[1].selected, true);
  });

  testWidgets('單一變體 → 沒有 ChoiceChip', (tester) async {
    await tester.pumpWidget(_app(spec: _spec(variants: const [DemoVariant('only', '唯一版本')])));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('顯示修正方、可信度與平台', (tester) async {
    const fixLabels = {
      FixSide.app: '修正在：App',
      FixSide.web: '修正在：網頁',
      FixSide.both: '修正在：兩邊',
      FixSide.either: '修正在：App 或網頁擇一',
    };
    for (final entry in fixLabels.entries) {
      await tester.pumpWidget(_app(spec: _spec(fixSide: entry.key)));
      expect(find.textContaining(entry.value), findsOneWidget, reason: '${entry.key}');
    }
    await tester.pumpWidget(_app(spec: _spec(fixSide: FixSide.none)));
    expect(find.textContaining('修正在：'), findsNothing);

    const confidenceLabels = {
      Confidence.verified: '已查證',
      Confidence.needsDeviceTest: '需實機確認',
      Confidence.observation: '觀察頁',
    };
    for (final entry in confidenceLabels.entries) {
      await tester.pumpWidget(_app(spec: _spec(confidence: entry.key)));
      expect(find.textContaining(entry.value), findsOneWidget, reason: '${entry.key}');
    }

    await tester.pumpWidget(_app(spec: _spec()));
    expect(find.text('修正在：兩邊 · 已查證 · 兩個平台'), findsOneWidget);
    await tester.pumpWidget(_app(spec: _spec(platform: DemoPlatform.android)));
    expect(find.textContaining('只有 Android'), findsOneWidget);
    await tester.pumpWidget(_app(spec: _spec(platform: DemoPlatform.ios)));
    expect(find.textContaining('只有 iOS'), findsOneWidget);
  });

  testWidgets('titleIsLiveRegion 為 true 時標題節點帶 liveRegion 旗標，false 時不帶', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(spec: _spec(), titleIsLiveRegion: true));
    expect(tester.getSemantics(find.text('網頁標題')), isSemantics(isLiveRegion: true));
    await tester.pumpWidget(_app(spec: _spec(), titleIsLiveRegion: false));
    expect(tester.getSemantics(find.text('網頁標題')), isSemantics(isLiveRegion: false));
    handle.dispose();
  });

  testWidgets('「怎麼測」展開後看得到前置、每一條步驟、兩段預期、依據', (tester) async {
    await tester.pumpWidget(_app(spec: _spec()));
    expect(find.text('怎麼測'), findsOneWidget);
    await tester.tap(find.text('怎麼測'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_howTo.setup), findsOneWidget);
    for (final step in _howTo.steps) {
      expect(find.textContaining(step), findsOneWidget);
    }
    expect(find.textContaining(_howTo.expectProblem), findsOneWidget);
    expect(find.textContaining(_howTo.expectFixed), findsOneWidget);
    for (final e in _howTo.evidence) {
      expect(find.textContaining(e), findsOneWidget);
    }
    for (final c in _howTo.codeRefs) {
      expect(find.textContaining(c), findsOneWidget);
    }
  });

  testWidgets('statusLine 顯示在畫面上；null 時不顯示', (tester) async {
    await tester.pumpWidget(_app(spec: _spec(), statusLine: const Text('網頁載入中')));
    expect(find.text('網頁載入中'), findsOneWidget);
    await tester.pumpWidget(_app(spec: _spec()));
    expect(find.text('網頁載入中'), findsNothing);
  });

  group('選項', () {
    const position = DemoOption('position', '按鈕位置', ['上方', '下方']);

    testWidgets('有 options 時看得到標籤與下拉選單；選另一個值後 onOptionChanged 收到 id 和值', (tester) async {
      String? changedId;
      String? changedValue;
      await tester.pumpWidget(_app(
        spec: _spec(options: const [position]),
        onOptionChanged: (id, value) {
          changedId = id;
          changedValue = value;
        },
      ));
      expect(find.text('按鈕位置'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      // options 裡沒有這一項時用 choices.first。
      expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value, '上方');

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下方').last);
      await tester.pumpAndSettle();
      expect(changedId, 'position');
      expect(changedValue, '下方');
    });

    testWidgets('目前的值來自 options', (tester) async {
      await tester.pumpWidget(_app(spec: _spec(options: const [position]), options: const {'position': '下方'}));
      expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value, '下方');
    });

    testWidgets('spec.options 是空的時沒有下拉選單', (tester) async {
      await tester.pumpWidget(_app(spec: _spec()));
      expect(find.byType(DropdownButton<String>), findsNothing);
    });
  });
}
