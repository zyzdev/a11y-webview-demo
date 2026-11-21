// 每個示範頁共用的頁框（設計文件 §5.4）：
//
//   AppBar（標題、動作按鈕）
//   變體選擇（一排可換行的 ChoiceChip）
//   選項（下拉選單）
//   標示列（修正在 · 可信度 · 平台）
//   ▸ 怎麼測（可收合）
//   狀態列（可為 null）
//   body（通常是 WebView）
//
// 狀態（目前的變體、選項的值）由呼叫端持有，這裡只負責畫與回呼。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../catalog/demo_spec.dart';
import 'how_to_test_panel.dart';

const double _dividerHeight = 1;

class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.spec,
    required this.variant,
    required this.onVariantChanged,
    required this.title,
    required this.titleIsLiveRegion,
    required this.body,
    this.options = const {},
    this.onOptionChanged,
    this.actions = const [],
    this.statusLine,
  });

  final DemoSpec spec;
  final DemoVariant variant;

  /// 使用者選了另一個變體時呼叫，參數是變體 id。
  final ValueChanged<String> onVariantChanged;

  /// AppBar 標題。
  final String title;

  /// 標題是否設成 liveRegion（設計文件 §6.4：預期標題改變時報讀器會念出，需實機確認；用在 C06 的變體）。
  final bool titleIsLiveRegion;

  final Widget body;

  /// 選項 id → 目前的值。沒有的項目用該選項 `choices` 的第一個。
  final Map<String, String> options;

  /// 使用者選了某個選項的另一個值時呼叫。null 時下拉選單停用。
  final void Function(String optionId, String value)? onOptionChanged;

  /// AppBar 的動作按鈕。
  final List<Widget> actions;

  /// 顯示在標示列和 body 之間的狀態文字。
  final Widget? statusLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec.variants.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final v in spec.variants)
                  ChoiceChip(
                    label: Text(v.label),
                    selected: v.id == variant.id,
                    onSelected: (_) {
                      if (v.id != variant.id) onVariantChanged(v.id);
                    },
                  ),
              ],
            ),
          ),
        for (final option in spec.options)
          if (option.choices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _OptionDropdown(
                option: option,
                value: options[option.id],
                onChanged: onOptionChanged,
              ),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(spec.badgeLine, style: theme.textTheme.bodyMedium),
        ),
        HowToTestPanel(howToTest: spec.howToTest),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Semantics(liveRegion: titleIsLiveRegion, child: Text(title)),
        actions: actions,
      ),
      // 不包 SafeArea：底部安全區域由各頁自己決定（C11 的「只改 App」就是用 SafeArea 包住 WebView），
      // 頁框若先包了，C11 的問題版就看不到問題（設計文件 §5.2 基準原則）。
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 控制區和狀態列合計最多佔一半高度（扣掉分隔線），body 永遠至少拿到一半；
          // 字級放大或「怎麼測」展開時才不會把 body 擠掉。
          final topMax = math.max(0.0, constraints.maxHeight / 2 - _dividerHeight);
          final status = statusLine;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: topMax),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 控制區拿狀態列用剩的高度，超過時在自己裡面捲動。
                    Flexible(child: SingleChildScrollView(child: controls)),
                    // 狀態列在控制區下方、body 正上方，不用捲動就看得到開頭（之後會是 liveRegion 的文字，
                    // 看不到就失去意義）。最多佔這一塊的一半，太長時在自己裡面捲動；它的 Semantics 原樣保留。
                    if (status != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: topMax / 2),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: status,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: _dividerHeight),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}

class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({required this.option, required this.value, required this.onChanged});

  final DemoOption option;
  final String? value;
  final void Function(String optionId, String value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final current = option.choices.contains(value) ? value! : option.choices.first;
    final callback = onChanged;
    // MergeSemantics：標籤和下拉選單合成一個節點。預期報讀器會把標籤、目前的值和「按鈕」一起念，
    // 不會把標籤念成獨立的一段文字（未在實機驗證）。
    return MergeSemantics(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: option.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current,
            isDense: true,
            isExpanded: true,
            items: [
              for (final choice in option.choices) DropdownMenuItem(value: choice, child: Text(choice)),
            ],
            onChanged: callback == null
                ? null
                : (selected) {
                    if (selected != null && selected != current) callback(option.id, selected);
                  },
          ),
        ),
      ),
    );
  }
}
