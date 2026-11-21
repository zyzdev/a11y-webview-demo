// 共用頁框裡可收合的「怎麼測」（設計文件 §5.4）：前置、步驟、預期、依據、看哪些檔案。

import 'package:flutter/material.dart';

import '../catalog/demo_spec.dart';

class HowToTestPanel extends StatelessWidget {
  const HowToTestPanel({super.key, required this.howToTest});

  final HowToTest howToTest;

  @override
  Widget build(BuildContext context) {
    final h = howToTest;
    return ExpansionTile(
      title: const Text('怎麼測'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: Alignment.centerLeft,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _Section(title: '前置', lines: [h.setup]),
        _Section(title: '步驟', lines: [for (var i = 0; i < h.steps.length; i++) '${i + 1}. ${h.steps[i]}']),
        _Section(title: '問題版預期', lines: [h.expectProblem]),
        _Section(title: '修正版預期', lines: [h.expectFixed]),
        if (h.evidence.isNotEmpty) _Section(title: '依據', lines: h.evidence),
        if (h.codeRefs.isNotEmpty) _Section(title: '看哪些檔案', lines: h.codeRefs),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小標題帶 header 語意，報讀器使用者可以用標題導覽在各段之間跳。
          Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall)),
          for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
