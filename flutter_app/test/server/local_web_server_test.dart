import 'dart:convert';
import 'dart:io';

import 'package:a11y_webview_demo/server/local_web_server.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用 dart:io 的 HttpClient 發一個請求，回傳狀態、標頭與 body。
Future<({int status, HttpHeaders headers, String body})> _send(Uri uri, {String method = 'GET'}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    return (status: response.statusCode, headers: response.headers, body: body);
  } finally {
    client.close(force: true);
  }
}

/// 用原始 Socket 送出請求，回傳回應的狀態列。HttpClient 送出前會把 '..' 正規化掉，所以路徑穿越只能這樣測。
Future<String> _rawStatusLine(Uri base, String requestText) async {
  final socket = await Socket.connect(base.host, base.port);
  try {
    socket.write(requestText);
    await socket.flush();
    final bytes = <int>[];
    await socket.listen(bytes.addAll).asFuture<void>().timeout(const Duration(seconds: 5));
    final text = latin1.decode(bytes);
    return text.split('\r\n').first;
  } finally {
    socket.destroy();
  }
}

void main() {
  group('LocalWebServer（HTTP 行為）', () {
    late List<String> requested;
    late Map<String, List<int>> files;
    late LocalWebServer server;

    setUp(() {
      requested = <String>[];
      files = {'index.html': utf8.encode('<h1>home</h1>'), 'shared/a11y-app.js': utf8.encode('var a=1;')};
      server = LocalWebServer(loader: (p) async {
        requested.add(p);
        return files[p];
      });
    });

    tearDown(() async {
      await server.stop();
    });

    test('start：host 為 127.0.0.1、port > 0、以 / 結尾；再呼叫一次 start 回傳同一個 Uri', () async {
      expect(server.baseUri, isNull);
      final uri = await server.start();
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, greaterThan(0));
      expect(uri.path, '/');
      expect(uri.toString(), 'http://127.0.0.1:${uri.port}/');
      expect(server.baseUri, uri);
      final again = await server.start();
      expect(again, uri);
    });

    test('GET / → 200，body、content-type、cache-control', () async {
      final base = await server.start();
      final res = await _send(base.resolve('/'));
      expect(res.status, 200);
      expect(res.body, '<h1>home</h1>');
      expect(res.headers.value('content-type'), 'text/html; charset=utf-8');
      expect(res.headers.value('cache-control'), 'no-store');
      expect(requested, contains('index.html'));
    });

    test('GET /shared/a11y-app.js?x=1 → 200，content-type 為 JavaScript', () async {
      final base = await server.start();
      final res = await _send(base.resolve('/shared/a11y-app.js?x=1'));
      expect(res.status, 200);
      expect(res.headers.value('content-type'), 'text/javascript; charset=utf-8');
      expect(res.body, 'var a=1;');
      expect(requested, contains('shared/a11y-app.js'));
    });

    test('GET /pages/missing.html → 404', () async {
      final base = await server.start();
      final res = await _send(base.resolve('/pages/missing.html'));
      expect(res.status, 404);
    });

    test('POST / → 405', () async {
      final base = await server.start();
      final res = await _send(base.resolve('/'), method: 'POST');
      expect(res.status, 405);
    });

    test('GET /index.html?__delay=80 → 200，耗時 ≥ 80ms', () async {
      final base = await server.start();
      final watch = Stopwatch()..start();
      final res = await _send(base.resolve('/index.html?__delay=80'));
      watch.stop();
      expect(res.status, 200);
      expect(res.body, '<h1>home</h1>');
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(80));
    });

    test('路徑穿越：原始 Socket 送 GET /../secret → 400 或 404，loader 沒收到含 .. 的路徑', () async {
      final base = await server.start();
      final statusLine = await _rawStatusLine(
          base, 'GET /../secret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      expect(statusLine, anyOf(startsWith('HTTP/1.1 400'), startsWith('HTTP/1.1 404')));
      expect(requested.where((p) => p.contains('..')), isEmpty);
    });

    test('路徑穿越：percent-encoded 的 %2e%2e 也擋掉', () async {
      final base = await server.start();
      final statusLine = await _rawStatusLine(
          base, 'GET /%2e%2e/secret HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      expect(statusLine, anyOf(startsWith('HTTP/1.1 400'), startsWith('HTTP/1.1 404')));
      expect(requested.where((p) => p.contains('..')), isEmpty);
    });

    test('stop 之後 start → 埠號和之前相同', () async {
      final first = await server.start();
      await _send(first.resolve('/'));
      await server.stop();
      expect(server.baseUri, isNull);
      final second = await server.start();
      expect(second.port, first.port);
      final res = await _send(second.resolve('/'));
      expect(res.status, 200);
    });

    test('debugCloseSocket 之後 ensureRunning → 埠號相同，GET / 回 200', () async {
      final first = await server.start();
      await server.debugCloseSocket();
      final again = await server.ensureRunning();
      expect(again.port, first.port);
      final res = await _send(again.resolve('/'));
      expect(res.status, 200);
      expect(res.body, '<h1>home</h1>');
    });

    test('ensureRunning：伺服器正常時回傳同一個 Uri', () async {
      final first = await server.start();
      final again = await server.ensureRunning();
      expect(again, first);
    });

    test('ensureRunning：原埠被佔時換埠，GET / 回 200', () async {
      final first = await server.start();
      await server.debugCloseSocket();
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, first.port);
      try {
        final again = await server.ensureRunning();
        expect(again.port, isNot(first.port));
        expect(again.host, '127.0.0.1');
        expect(again.path, '/');
        final res = await _send(again.resolve('/'));
        expect(res.status, 200);
      } finally {
        await blocker.close();
      }
    });

    test('ensureRunning：原埠被別的 HTTP 伺服器佔走時，不把它當成自己，換埠重啟', () async {
      final first = await server.start();
      await server.debugCloseSocket();
      final foreign = await HttpServer.bind(InternetAddress.loopbackIPv4, first.port);
      foreign.listen((request) {
        request.response
          ..statusCode = 200
          ..write('foreign')
          ..close();
      });
      try {
        final again = await server.ensureRunning();
        expect(again.port, isNot(first.port));
        expect(server.baseUri, again);
        final res = await _send(again.resolve('/'));
        expect(res.status, 200);
        expect(res.body, '<h1>home</h1>');
      } finally {
        await foreign.close(force: true);
      }
    });

    test('查詢字串解不開（%ff）時視為沒有延遲，照常回 200', () async {
      final base = await server.start();
      final plain = await _rawStatusLine(
          base, 'GET /?x=%ff HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      expect(plain, startsWith('HTTP/1.1 200'));
      final delayed = await _rawStatusLine(
          base, 'GET /index.html?__delay=%ff HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
      expect(delayed, startsWith('HTTP/1.1 200'));
      expect(requested, ['index.html', 'index.html']);
    });
  });

  group('LocalWebServer（靜態方法）', () {
    test('contentTypeFor', () {
      expect(LocalWebServer.contentTypeFor('a.css'), 'text/css; charset=utf-8');
      expect(LocalWebServer.contentTypeFor('a.svg'), 'image/svg+xml');
      expect(LocalWebServer.contentTypeFor('a.png'), 'image/png');
      expect(LocalWebServer.contentTypeFor('a.json'), 'application/json; charset=utf-8');
      expect(LocalWebServer.contentTypeFor('a.mjs'), 'text/javascript; charset=utf-8');
      expect(LocalWebServer.contentTypeFor('a.bin'), 'application/octet-stream');
      expect(LocalWebServer.contentTypeFor('a.html'), 'text/html; charset=utf-8');
      expect(LocalWebServer.contentTypeFor('a.js'), 'text/javascript; charset=utf-8');
    });

    test('normalizePath', () {
      expect(LocalWebServer.normalizePath('/'), 'index.html');
      expect(LocalWebServer.normalizePath('/pages/'), 'pages/index.html');
      expect(LocalWebServer.normalizePath('/a/../b'), isNull);
      expect(LocalWebServer.normalizePath('/shared/a11y-app.js'), 'shared/a11y-app.js');
      expect(LocalWebServer.normalizePath('/../secret'), isNull);
      expect(LocalWebServer.normalizePath('/%2e%2e/secret'), isNull);
      // 無法解碼：%zz 不是合法的 percent-encoding；%ff 解出來不是合法的 UTF-8。
      expect(LocalWebServer.normalizePath('/%zz'), isNull);
      expect(LocalWebServer.normalizePath('/%ff'), isNull);
      // 解碼後含 /、\、NUL 的段落。
      expect(LocalWebServer.normalizePath('/..%2fsecret'), isNull);
      expect(LocalWebServer.normalizePath('/%5c..%5csecret'), isNull);
      expect(LocalWebServer.normalizePath('/%00'), isNull);
    });

    test('parseDelay', () {
      expect(LocalWebServer.parseDelay('80'), const Duration(milliseconds: 80));
      expect(LocalWebServer.parseDelay('999999'), const Duration(seconds: 10));
      expect(LocalWebServer.parseDelay('-5'), Duration.zero);
      expect(LocalWebServer.parseDelay('abc'), Duration.zero);
      expect(LocalWebServer.parseDelay(null), Duration.zero);
    });
  });
}
