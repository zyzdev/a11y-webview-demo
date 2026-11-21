import 'package:flutter/material.dart';

// 暫時的最小畫面，Task 4 會整個改寫。
void main() {
  runApp(const A11yWebViewDemoApp());
}

class A11yWebViewDemoApp extends StatelessWidget {
  const A11yWebViewDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'WebView 無障礙範例',
      home: Scaffold(
        body: Center(child: Text('WebView 無障礙範例')),
      ),
    );
  }
}
