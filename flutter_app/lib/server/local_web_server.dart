// App 內建的網頁伺服器（設計文件 §5.1）。
//
// 用 dart:io 的 HttpServer 綁在 127.0.0.1（不用 localhost，避免解析到 IPv6），從 App 的 assets
// 提供 web/ 的內容。用 HTTP 而不是 file://，WebView、In-app browser 和一般瀏覽器才能開同一份網頁，
// 也才能帶查詢參數、用 history.pushState。
//
// 這個伺服器只適合示範：同一台裝置上的其他 App 也連得到它。正式專案的網頁來自 HTTPS 網站，
// 不需要這個伺服器。

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 依相對路徑（例如 `pages/b-content.html`）讀檔。找不到回傳 null。
typedef AssetLoader = Future<List<int>?> Function(String relativePath);

class LocalWebServer {
  LocalWebServer({required this._loader});

  final AssetLoader _loader;

  HttpServer? _server;
  Uri? _baseUri;

  /// 上一次成功綁定的埠。stop 之後仍保留，下次啟動優先用它，網址才不會變。
  int? _lastPort;

  /// 讓 start、stop、ensureRunning 依序執行，避免同時啟動兩次。
  Future<void> _queue = Future<void>.value();

  /// 目前的網址，例如 `http://127.0.0.1:53124/`，一律以 `/` 結尾。尚未啟動或已停止時為 null。
  Uri? get baseUri => _baseUri;

  /// 啟動伺服器。已啟動時回傳現有的 [baseUri]。
  Future<Uri> start() => _exclusive(_startLocked);

  /// 停止伺服器。之後再 [start] 會優先使用同一個埠。
  Future<void> stop() => _exclusive(() async {
        final server = _server;
        _server = null;
        _baseUri = null;
        await server?.close(force: true);
      });

  /// 確認伺服器還能回應（iOS 會在 App 暫停時回收 socket）。
  ///
  /// 自我探測失敗時優先在原埠重新啟動，原埠被佔用才換埠。
  Future<Uri> ensureRunning() => _exclusive(() async {
        final current = _baseUri;
        if (_server == null || current == null) return _startLocked();
        if (await _probe(current)) return current;
        final stale = _server;
        _server = null;
        _baseUri = null;
        try {
          await stale?.close(force: true);
        } catch (_) {
          // socket 已經被系統回收時關閉可能失敗，不影響重新啟動。
        }
        return _startLocked();
      });

  /// 只關底層 HttpServer、不清狀態，模擬 socket 被系統回收。
  @visibleForTesting
  Future<void> debugCloseSocket() async {
    await _server?.close(force: true);
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    return previous.then((_) => action()).whenComplete(done.complete);
  }

  Future<Uri> _startLocked() async {
    final existing = _baseUri;
    if (_server != null && existing != null) return existing;

    HttpServer server;
    final preferred = _lastPort;
    if (preferred != null) {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, preferred);
      } on SocketException {
        // 原埠被佔用才換埠。
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
    } else {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }

    server.listen(
      (request) => unawaited(_handle(request)),
      // socket 被系統回收時串流可能報錯；交給 ensureRunning 的探測處理，不讓錯誤冒出去。
      onError: (Object _) {},
    );
    _server = server;
    _lastPort = server.port;
    final uri = Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/');
    _baseUri = uri;
    return uri;
  }

  /// 對自己發一個請求。收到任何 HTTP 回應就算活著。
  Future<bool> _probe(Uri base) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(base).timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>().timeout(const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      if (request.method != 'GET') {
        response.headers.set(HttpHeaders.allowHeader, 'GET');
        _plain(response, HttpStatus.methodNotAllowed, 'Method Not Allowed');
        return;
      }
      final path = normalizePath(request.uri.path);
      if (path == null) {
        _plain(response, HttpStatus.badRequest, 'Bad Request');
        return;
      }
      final delay = parseDelay(request.uri.queryParameters['__delay']);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final bytes = await _loader(path);
      if (bytes == null) {
        _plain(response, HttpStatus.notFound, 'Not Found');
        return;
      }
      response.statusCode = HttpStatus.ok;
      response.headers.set(HttpHeaders.contentTypeHeader, contentTypeFor(path));
      response.contentLength = bytes.length;
      response.add(bytes);
    } catch (_) {
      try {
        _plain(response, HttpStatus.internalServerError, 'Internal Server Error');
      } catch (_) {
        // 標頭已送出時無法再改狀態碼。
      }
    } finally {
      try {
        await response.close();
      } catch (_) {
        // 用戶端已經斷線。
      }
    }
  }

  static void _plain(HttpResponse response, int status, String message) {
    response.statusCode = status;
    response.headers.set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8');
    response.write(message);
  }

  /// 把請求路徑轉成 assets 裡的相對路徑。
  ///
  /// `/` → `index.html`，以 `/` 結尾的目錄補上 `index.html`。任何一段（percent-decode 之後）是 `..`
  /// 或 `.`、含有 `/`、`\` 或 NUL，或無法解碼，都回傳 null。
  static String? normalizePath(String rawPath) {
    var path = rawPath;
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty || path.endsWith('/')) path = '${path}index.html';
    final segments = <String>[];
    for (final raw in path.split('/')) {
      String segment;
      try {
        segment = Uri.decodeComponent(raw);
      } on ArgumentError {
        return null;
      }
      if (segment.isEmpty || segment == '.' || segment == '..') return null;
      if (segment.contains('/') || segment.contains(r'\') || segment.contains('\u0000')) return null;
      segments.add(segment);
    }
    return segments.join('/');
  }

  static const Map<String, String> _contentTypes = {
    'html': 'text/html; charset=utf-8',
    'htm': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'txt': 'text/plain; charset=utf-8',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'ico': 'image/x-icon',
    'woff2': 'font/woff2',
  };

  /// 依副檔名回傳 Content-Type。不認得的副檔名回傳 `application/octet-stream`。
  static String contentTypeFor(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return 'application/octet-stream';
    return _contentTypes[name.substring(dot + 1).toLowerCase()] ?? 'application/octet-stream';
  }

  static const int _maxDelayMs = 10000;

  /// 解析查詢參數 `__delay`（毫秒），用來模擬慢速載入。限制在 0–10000；不合法回傳 0。
  static Duration parseDelay(String? raw) {
    if (raw == null) return Duration.zero;
    final ms = int.tryParse(raw);
    if (ms == null || ms < 0) return Duration.zero;
    return Duration(milliseconds: ms > _maxDelayMs ? _maxDelayMs : ms);
  }
}

/// 從 App 的 assets 讀檔（預設 `assets/web/`）。找不到回傳 null。
AssetLoader rootBundleLoader({String prefix = 'assets/web/'}) {
  return (relativePath) async {
    try {
      final data = await rootBundle.load('$prefix$relativePath');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on FlutterError {
      // 找不到 asset 時 rootBundle 丟 FlutterError。
      return null;
    }
  };
}
