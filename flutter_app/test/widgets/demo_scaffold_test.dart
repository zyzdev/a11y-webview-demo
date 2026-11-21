import 'dart:math' as math;

import 'package:a11y_webview_demo/catalog/demo_spec.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:a11y_webview_demo/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('大字級版面：控制區加狀態列最多佔一半，body 至少拿到一半，狀態列不用捲動就看得到', () {
    const fourVariants = [
      DemoVariant('problem', '問題版', webMode: 'problem'),
      DemoVariant('web-focus', '網頁移焦點'),
      DemoVariant('live-region', 'App 用 liveRegion'),
      DemoVariant('announce', 'App 用 sendAnnouncement'),
    ];
    const status = 'Flutter 在這個平台不支援 announcement，請用 liveRegion';
    const bodyKey = Key('body');

    Widget scaffold({required bool withStatus}) => MaterialApp(
          home: DemoScaffold(
            spec: _spec(variants: fourVariants),
            variant: fourVariants.first,
            onVariantChanged: (_) {},
            title: '頁面抵達：朗讀與焦點',
            titleIsLiveRegion: false,
            body: const SizedBox.expand(key: bodyKey),
            statusLine: withStatus ? Semantics(liveRegion: true, child: const Text(status)) : null,
          ),
        );

    /// 不捲動，直接檢查：沒有例外、body 至少一半、狀態列和可視範圍有交集、語意不是 hidden 且帶 liveRegion。
    Future<void> expectStatusVisible(WidgetTester tester, String label) async {
      expect(tester.takeException(), isNull);
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      final bodyRect = tester.getRect(find.byKey(bodyKey));
      final area = bodyRect.bottom - appBarBottom;
      expect(bodyRect.height, greaterThanOrEqualTo(area / 2), reason: '$label：body ${bodyRect.height} / 區域 $area');

      // 可視範圍 = AppBar 與 body 之間，再和狀態列所在捲動區的範圍取交集（被捲動區裁掉的部分看不到）。
      final statusRect = tester.getRect(find.text(status));
      final viewport = tester.getRect(find.ancestor(of: find.text(status), matching: find.byType(Scrollable)).first);
      final visibleTop = [statusRect.top, viewport.top, appBarBottom].reduce((a, b) => a > b ? a : b);
      final visibleBottom = [statusRect.bottom, viewport.bottom, bodyRect.top].reduce((a, b) => a < b ? a : b);
      final visible = visibleBottom - visibleTop;
      expect(visible, greaterThan(0), reason: '$label：狀態列看得到的高度 $visible／${statusRect.height}');
      // 「看得到開頭」：至少一行字（14 × 字級）的高度在可視範圍內，文字比一行短時整段都要在內。
      final scale = MediaQuery.textScalerOf(tester.element(find.text(status))).scale(14);
      expect(visible, greaterThanOrEqualTo(math.min(statusRect.height, scale)),
          reason: '$label：狀態列看得到的高度 $visible，不到一行（$scale）');
      expect(statusRect.top, lessThan(bodyRect.top));

      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(tester.getSemantics(find.text(status)), isSemantics(isLiveRegion: true, isHidden: false, label: status),
          reason: label);
      handle.dispose();
      expect(tester.takeException(), isNull);
    }

    Future<void> setUpView(WidgetTester tester, Size size, double scale) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    Future<void> expand(WidgetTester tester) async {
      // 控制區的捲動區可能小到「怎麼測」在可視範圍外，先捲到它（只捲控制區，不捲狀態列）。
      await tester.ensureVisible(find.text('怎麼測'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('怎麼測'));
      await tester.pumpAndSettle();
      expect(find.textContaining(_howTo.expectFixed), findsOneWidget);
    }

    const cases = [
      (Size(390, 844), 3.0, false),
      (Size(320, 568), 2.0, false),
      (Size(320, 568), 3.0, false),
      (Size(568, 320), 3.0, false),
      (Size(320, 568), 1.0, false),
      (Size(390, 844), 1.0, true),
      (Size(320, 568), 1.0, true),
    ];

    for (final (size, scale, expanded) in cases) {
      final label = '${size.width.toInt()}×${size.height.toInt()}、字級 $scale、「怎麼測」${expanded ? '展開' : '收合'}';
      testWidgets(label, (tester) async {
        await setUpView(tester, size, scale);
        await tester.pumpWidget(scaffold(withStatus: true));
        if (expanded) await expand(tester);
        await expectStatusVisible(tester, label);
      });

      testWidgets('$label：statusLine 先是 null、重建後才出現', (tester) async {
        await setUpView(tester, size, scale);
        await tester.pumpWidget(scaffold(withStatus: false));
        if (expanded) await expand(tester);
        expect(find.text(status), findsNothing);
        await tester.pumpWidget(scaffold(withStatus: true));
        await expectStatusVisible(tester, '$label（後出現）');
      });
    }
  });

  // 外接鍵盤（設計文件 B05）：行動平台上沒指定 controller 的直向捲動區會接上 PrimaryScrollController，
  // 同一個 controller 掛兩個捲動位置時，PageDown 的 ScrollAction 會丟例外。
  testWidgets('有狀態列、字級 3.0 時按實體鍵盤 PageDown 不丟例外', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
      home: DemoScaffold(
        spec: _spec(),
        variant: kProblemFixed.first,
        onVariantChanged: (_) {},
        title: '網頁標題',
        titleIsLiveRegion: false,
        // 讓頁框裡有東西取得焦點，鍵盤事件才會經過 Shortcuts／Actions。
        body: Focus(autofocus: true, child: const SizedBox.expand()),
        statusLine: Semantics(liveRegion: true, child: const Text('Flutter 在這個平台不支援 announcement，請用 liveRegion')),
      ),
    ));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));
}
