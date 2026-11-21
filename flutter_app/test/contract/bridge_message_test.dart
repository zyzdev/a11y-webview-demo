import 'package:a11y_webview_demo/contract/bridge_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready', () {
    final ready = BridgeMessage.parse('{"type":"ready","title":"字體大小","lang":"zh-TW","contract":1,"caps":["textScale","theme"]}') as ReadyMessage;
    expect(ready.title, '字體大小'); expect(ready.contract, 1); expect(ready.caps, ['textScale', 'theme']);
    expect(ready.lang, 'zh-TW');
    final bare = BridgeMessage.parse('{"type":"ready","title":"x"}') as ReadyMessage;
    expect(bare.contract, 0); expect(bare.caps, isEmpty); expect(bare.lang, isNull);
  });

  test('routeChanged', () {
    expect(BridgeMessage.parse('{"type":"routeChanged","title":"詳情","path":"/detail"}'), isA<RouteChangedMessage>());
    final route = BridgeMessage.parse('{"type":"routeChanged","title":"詳情","path":"/detail"}') as RouteChangedMessage;
    expect(route.title, '詳情'); expect(route.path, '/detail');
  });

  test('backState', () {
    expect(BridgeMessage.parse('{"type":"backState","canHandleBack":true}'), isA<BackStateMessage>().having((m) => m.canHandleBack, 'v', true));
  });

  test('openNativeDialog', () {
    expect(BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"刪除","message":"確定？","actions":["取消","刪除"]}'),
        isA<OpenNativeDialogMessage>().having((m) => m.actions, 'actions', ['取消', '刪除']));
    final dialog = BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"刪除","message":"確定？","actions":["取消","刪除"]}')
        as OpenNativeDialogMessage;
    expect(dialog.requestId, 'r1'); expect(dialog.title, '刪除'); expect(dialog.message, '確定？');
  });

  test('formResult', () {
    expect(BridgeMessage.parse('{"type":"formResult","ok":false,"errorCount":2,"firstError":"請輸入姓名"}'), isA<FormResultMessage>());
    final failed = BridgeMessage.parse('{"type":"formResult","ok":false,"errorCount":2,"firstError":"請輸入姓名"}') as FormResultMessage;
    expect(failed.ok, false); expect(failed.errorCount, 2); expect(failed.firstError, '請輸入姓名');
    expect((BridgeMessage.parse('{"type":"formResult","ok":true,"errorCount":0}') as FormResultMessage).firstError, '');
  });

  test('close', () {
    expect(BridgeMessage.parse('{"type":"close"}'), isA<CloseMessage>());
  });

  test('invalid input is ignored', () {
    expect(BridgeMessage.parse('not json'), isNull);
    expect(BridgeMessage.parse('[]'), isNull);
    expect(BridgeMessage.parse('{"type":"unknown"}'), isNull);
    expect(BridgeMessage.parse('{"type":"ready"}'), isNull);                            // 缺必要欄位
    expect(BridgeMessage.parse('{"type":"backState","canHandleBack":"yes"}'), isNull);  // 型別不對
    expect(BridgeMessage.parse(''), isNull);
    expect(BridgeMessage.parse('null'), isNull);
    expect(BridgeMessage.parse('{}'), isNull);
    expect(BridgeMessage.parse('{"type":1}'), isNull);
    expect(BridgeMessage.parse('{"type":"routeChanged","title":"x"}'), isNull);
    expect(BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"t","message":"m"}'), isNull);
    expect(BridgeMessage.parse('{"type":"formResult","ok":true}'), isNull);
    expect(BridgeMessage.parse('{"type":"formResult","ok":true,"errorCount":1.5}'), isNull);
  });

  test('optional fields present with the wrong type reject the whole message', () {
    expect(BridgeMessage.parse('{"type":"ready","title":"x","contract":"1"}'), isNull);
    expect(BridgeMessage.parse('{"type":"ready","title":"x","lang":1}'), isNull);
    expect(BridgeMessage.parse('{"type":"ready","title":"x","caps":"textScale"}'), isNull);
    expect(BridgeMessage.parse('{"type":"formResult","ok":false,"errorCount":1,"firstError":3}'), isNull);
  });

  test('explicit null for an optional field means absent', () {
    final ready = BridgeMessage.parse('{"type":"ready","title":"x","lang":null,"contract":null,"caps":null}') as ReadyMessage;
    expect(ready.lang, isNull); expect(ready.contract, 0); expect(ready.caps, isEmpty);
  });

  test('list elements must all be strings', () {
    expect(BridgeMessage.parse('{"type":"ready","title":"x","caps":["textScale",1]}'), isNull);
    expect(BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"t","message":"m","actions":["ok",null]}'), isNull);
  });

  test('parsed lists are real, unmodifiable List<String>', () {
    final ready = BridgeMessage.parse('{"type":"ready","title":"x","caps":["textScale"]}') as ReadyMessage;
    expect(ready.caps, isA<List<String>>());
    expect(() => ready.caps.add('theme'), throwsUnsupportedError);
  });

  test('string fields are truncated to 200 characters', () {
    final long = BridgeMessage.parse('{"type":"ready","title":"${'字' * 500}"}') as ReadyMessage;
    expect(long.title.length, 200);                                                      // 字串欄位截到 200 字
    final dialog = BridgeMessage.parse('{"type":"openNativeDialog","requestId":"r1","title":"t","message":"${'m' * 300}",'
        '"actions":["${'a' * 300}"]}') as OpenNativeDialogMessage;
    expect(dialog.message.length, 200);
    expect(dialog.actions.single.length, 200);                                           // 清單裡的字串也截
    // 以字（Unicode code point）計算，不會把 UTF-16 代理對切成一半。
    final emoji = BridgeMessage.parse('{"type":"routeChanged","title":"${'😀' * 300}","path":"/"}') as RouteChangedMessage;
    expect(emoji.title.runes.length, 200);
    expect(emoji.title, '😀' * 200);
  });

  test('messages can be constructed directly', () {
    const ready = ReadyMessage(title: 't');
    expect(ready.lang, isNull); expect(ready.contract, 0); expect(ready.caps, isEmpty);
    const form = FormResultMessage(ok: true, errorCount: 0);
    expect(form.firstError, '');
    const messages = <BridgeMessage>[
      ReadyMessage(title: 't', lang: 'zh-TW', contract: 1, caps: ['theme']),
      RouteChangedMessage(title: 't', path: '/'),
      BackStateMessage(canHandleBack: true),
      OpenNativeDialogMessage(requestId: 'r', title: 't', message: 'm', actions: ['ok']),
      FormResultMessage(ok: false, errorCount: 1, firstError: 'e'),
      CloseMessage(),
    ];
    expect(messages, hasLength(6));
  });
}
