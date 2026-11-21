// 網頁 → App 的訊息（設計文件 §6.3）。網頁用 `A11yBridge.postMessage(JSON)` 送來。
// 純 Dart，不依賴 Flutter。網頁端的送出邏輯在 web/shared/a11y-app.js（postToApp）。
//
// 訊息是外來的資料：無法解析、不認得的 type、缺必要欄位、欄位型別不對，一律回傳 null 讓 App 忽略，
// 不丟例外（設計文件 §6.3：App 收到無法解析或不認得的訊息時忽略，不能當掉）。
// 可省略的欄位沒帶或是 null 時用預設值；有帶但型別不對時，整則訊息視為不合法。

import 'dart:convert';

/// 字串欄位（包括清單裡的每個字串）最多保留的字數，以 Unicode code point 計。
const int _maxStringLength = 200;

sealed class BridgeMessage {
  const BridgeMessage();

  /// 解析一則訊息；不合法時回傳 null。
  static BridgeMessage? parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final json = _Fields(decoded);
    try {
      return switch (decoded['type']) {
        'ready' => ReadyMessage(
            title: json.requiredString('title'),
            lang: json.optionalString('lang'),
            contract: json.optionalInt('contract') ?? 0,
            caps: json.optionalStringList('caps') ?? const [],
          ),
        'routeChanged' => RouteChangedMessage(
            title: json.requiredString('title'),
            path: json.requiredString('path'),
          ),
        'backState' => BackStateMessage(canHandleBack: json.requiredBool('canHandleBack')),
        'openNativeDialog' => OpenNativeDialogMessage(
            requestId: json.requiredString('requestId'),
            title: json.requiredString('title'),
            message: json.requiredString('message'),
            actions: json.requiredStringList('actions'),
          ),
        'formResult' => FormResultMessage(
            ok: json.requiredBool('ok'),
            errorCount: json.requiredInt('errorCount'),
            firstError: json.optionalString('firstError') ?? '',
          ),
        'close' => const CloseMessage(),
        _ => null,
      };
    } on _InvalidField {
      return null;
    }
  }
}

/// 頁面可用了。`contract` 是約定版本，`caps` 是這一頁目前啟用的修正名稱。
final class ReadyMessage extends BridgeMessage {
  const ReadyMessage({required this.title, this.lang, this.contract = 0, this.caps = const []});
  final String title;
  final String? lang;
  final int contract;
  final List<String> caps;
}

/// 網頁內換頁。
final class RouteChangedMessage extends BridgeMessage {
  const RouteChangedMessage({required this.title, required this.path});
  final String title;
  final String path;
}

/// 網頁內有沒有對話框之類要先關的東西。
final class BackStateMessage extends BridgeMessage {
  const BackStateMessage({required this.canHandleBack});
  final bool canHandleBack;
}

/// 請 App 顯示原生對話框；關閉後用 `onNativeDialogClosed(requestId, action)` 回覆。
final class OpenNativeDialogMessage extends BridgeMessage {
  const OpenNativeDialogMessage({required this.requestId, required this.title, required this.message, required this.actions});
  final String requestId, title, message;
  final List<String> actions;
}

/// 表單驗證或送出的結果。
final class FormResultMessage extends BridgeMessage {
  const FormResultMessage({required this.ok, required this.errorCount, this.firstError = ''});
  final bool ok;
  final int errorCount;
  final String firstError;
}

/// 請 App 關閉整個 WebView 畫面。
final class CloseMessage extends BridgeMessage {
  const CloseMessage();
}

class _InvalidField implements Exception {
  const _InvalidField();
}

/// 逐欄檢查型別的小工具。檢查不過就丟 [_InvalidField]，由 [BridgeMessage.parse] 轉成 null。
extension type const _Fields(Map<String, dynamic> map) {
  String requiredString(String key) {
    final value = map[key];
    if (value is! String) throw const _InvalidField();
    return _truncate(value);
  }

  String? optionalString(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) throw const _InvalidField();
    return _truncate(value);
  }

  bool requiredBool(String key) {
    final value = map[key];
    if (value is! bool) throw const _InvalidField();
    return value;
  }

  int requiredInt(String key) {
    final value = map[key];
    if (value is! int) throw const _InvalidField();
    return value;
  }

  int? optionalInt(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! int) throw const _InvalidField();
    return value;
  }

  List<String> requiredStringList(String key) {
    final value = map[key];
    if (value == null) throw const _InvalidField();
    return _stringList(value);
  }

  List<String>? optionalStringList(String key) {
    final value = map[key];
    if (value == null) return null;
    return _stringList(value);
  }

  // 當場檢查每個元素並建出真正的 List<String>（不用 lazy 的 cast，免得之後才出錯）。
  static List<String> _stringList(Object value) {
    if (value is! List) throw const _InvalidField();
    final result = <String>[];
    for (final item in value) {
      if (item is! String) throw const _InvalidField();
      result.add(_truncate(item));
    }
    return List.unmodifiable(result);
  }

  // 以 code point 計算，不會把 UTF-16 代理對切成一半。
  static String _truncate(String value) {
    if (value.length <= _maxStringLength) return value;
    final runes = value.runes;
    if (runes.length <= _maxStringLength) return value;
    return String.fromCharCodes(runes.take(_maxStringLength));
  }
}
